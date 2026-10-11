classdef PipelineDataProcessor
    % Single Source of Truth for Data Loading, Feature Engineering, and Preprocessing
    
    methods (Static)
        function [fullData, X, Y] = prepareData(featureList, interval, maxRows)
            if nargin < 2; interval = '1d'; end
            if nargin < 3; maxRows = []; end
            
            % 1. Load Market Data
            loader = PriceDataLoader('BTCUSDT', interval);
            if strcmp(interval, '1d')
                marketFile = fullfile(pwd, 'data', 'market', 'btc.csv');
            elseif strcmp(interval, '15m')
                marketFile = fullfile(pwd, 'data', 'market', 'btc_15m_data_2018_to_2025.csv');
            else
                marketFile = fullfile(pwd, 'data', 'market', ['btc_', interval, '.csv']);
            end
            try
                marketData = loader.loadHistoricalCSV(marketFile);
            catch
                % Fallback for legacy filenames
                if strcmp(interval, '15m')
                    marketData = loader.loadHistoricalCSV(fullfile(pwd, 'data', 'market', 'btc_15m_data_2018_to_2025.csv'));
                else
                    marketData = loader.loadHistoricalCSV(fullfile(pwd, 'btc.csv'));
                end
            end
            
            if ~isempty(maxRows) && height(marketData) > maxRows
                marketData = marketData(end-maxRows+1:end, :);
            end

            
            % 2. Load Sentiment Data
            try
                sentimentData = readtable('data/sentiment/historical_daily_sentiment.csv');
            catch
                Logger.warning('Sentiment dataset missing. Generating it...');
                engine = SentimentEngine();
                engine.processHistoricalTweets();
                sentimentData = readtable('data/sentiment/historical_daily_sentiment.csv');
            end
            
            % 3. Merge and Align on a Continuous Grid
            % The reviewer identified gaps in the time-series which break autoregressive models.
            % We create a continuous regular grid and synchronize to prevent alignment issues.
            % Standardize column names
            if any(strcmp(marketData.Properties.VariableNames, 'Open_time'))
               marketData.Properties.VariableNames{'Open_time'} = 'Date';
            elseif any(strcmp(marketData.Properties.VariableNames, 'Open time'))
               marketData.Properties.VariableNames{'Open time'} = 'Date';
            elseif any(strcmp(marketData.Properties.VariableNames, 'OpenTime'))
               marketData.Properties.VariableNames{'OpenTime'} = 'Date';
            end
            marketData.Date = datetime(marketData.Date);
            % Remove rows with NaT date early
            marketData(isnat(marketData.Date), :) = [];
            
            % Apply +1 calendar-day lag to sentiment to ensure no look-ahead.
            sentimentData.Date = dateshift(datetime(sentimentData.Date), 'start', 'day') + caldays(1);
            
             % Convert to timetables for explicit alignment
            marketTT = table2timetable(marketData, 'RowTimes', 'Date');
            sentimentTT = table2timetable(sentimentData, 'RowTimes', 'Date');
            
            % Remove duplicate timestamps: 
            [~, idxM] = unique(marketTT.Date); % unique automatically sorts
            marketTT = marketTT(idxM, :);
            
            [~, idxS] = unique(sentimentTT.Date); % unique automatically sorts
            sentimentTT = sentimentTT(idxS, :);

            % Final safety sort
            marketTT = sortrows(marketTT, 'Date');
            sentimentTT = sortrows(sentimentTT, 'Date');
            
            fprintf('Market TT Type: %s, Sentiment TT Type: %s\n', class(marketTT.Properties.RowTimes), class(sentimentTT.Properties.RowTimes));
            fprintf('Market TT Timezone: %s, Sentiment TT Timezone: %s\n', marketTT.Properties.RowTimes.TimeZone, sentimentTT.Properties.RowTimes.TimeZone);
            
            % Synchronize onto a continuous grid

            if strcmp(interval, '1d')
                fullDataTT = synchronize(marketTT, sentimentTT, 'daily', 'previous');
            elseif strcmp(interval, '15m')
                % Create an explicit datetime grid
                startTime = min(min(marketTT.Date), min(sentimentTT.Date));
                endTime = max(max(marketTT.Date), max(sentimentTT.Date));
                regularGrid = (startTime:minutes(15):endTime)';
                
                fprintf('Grid Size: %d, Start: %s, End: %s\n', length(regularGrid), char(regularGrid(1)), char(regularGrid(end)));
                fprintf('Market TT Start: %s, End: %s\n', char(marketTT.Date(1)), char(marketTT.Date(end)));
                
                fullDataTT = synchronize(marketTT, sentimentTT, regularGrid, 'previous');
            else
                fullDataTT = synchronize(marketTT, sentimentTT, 'daily', 'previous');
            end
            
            % Convert back to table
            fullData = timetable2table(fullDataTT);
            % Rename Time back to Date
            fullData.Properties.VariableNames{1} = 'Date';
            
            % Drop rows where market data is missing before the first available date
            fullData = rmmissing(fullData, 'DataVariables', 'Close');
            % Note: sentiment might still have NaNs early on; we replace them with 0 (neutral sentiment)
            if any(ismissing(fullData.Daily_Sentiment))
                fullData.Daily_Sentiment(ismissing(fullData.Daily_Sentiment)) = 0;
            end
            if any(ismissing(fullData.Tweet_Volume))
                fullData.Tweet_Volume(ismissing(fullData.Tweet_Volume)) = 0;
            end
            
            % 4. Technical Indicators
            fullData = IndicatorEngine.calculateAll(fullData);
            
            % 5. Targets (shifted closing prices)
            fullData.Target = [fullData.Close(2:end); NaN];
            
            % Identify synthetic forward-filled grid rows to construct a TargetEligibility mask
            % Preserve the complete chronological grid for indicator memory and lookback context,
            % but mark synthetic target labels as NaN so supervised training loss ignores them.
            if strcmp(interval, '15m')
                try
                    rawMarket = readtable(fullfile(pwd, 'data', 'market', 'btc_15m_data_2018_to_2025.csv'), 'VariableNamingRule', 'preserve');
                    if any(strcmp(rawMarket.Properties.VariableNames, 'Open_time'))
                       rawMarket.Properties.VariableNames{'Open_time'} = 'Date';
                    elseif any(strcmp(rawMarket.Properties.VariableNames, 'Open time'))
                       rawMarket.Properties.VariableNames{'Open time'} = 'Date';
                    elseif any(strcmp(rawMarket.Properties.VariableNames, 'OpenTime'))
                       rawMarket.Properties.VariableNames{'OpenTime'} = 'Date';
                    end
                    rawDates = datetime(rawMarket.Date);
                    rawDatesClean = rawDates(~isnat(rawDates));
                    isSynth = ~ismember(fullData.Date, rawDatesClean);
                    % Target(t) corresponds to Close(t+1), so check observation status at t+1
                    targetIsSynth = [isSynth(2:end); false];
                    
                    % Explicitly set Target to NaN for synthetic rows without deleting grid rows
                    fullData.Target(targetIsSynth) = NaN;
                catch
                end
            end
            
            fullData(end, :) = [];
            
            % 6. Features & Labels
            if nargin < 1 || isempty(featureList)
                featureList = {'Open', 'High', 'Low', 'Close', 'Volume', 'SMA_20', 'SMA_50', ...
                    'EMA_20', 'EMA_50', 'MACD_Line', 'MACD_Signal', 'MACD_Hist', 'RSI_14', ...
                    'BB_Upper', 'BB_Lower', 'VWAP', 'Volatility_20', 'ATR_14', ...
                    'Daily_Sentiment', 'Tweet_Volume'};
            end
            X = fullData{:, featureList};
            Y = fullData.Target;
        end
        
        function X_scaled = scaleData(X, scaler)
            range = scaler.Max - scaler.Min;
            range(range == 0) = 1;
            X_scaled = (X - scaler.Min) ./ range;
        end
        
        function Y_scaled = scaleTarget(Y, targetScaler)
            range = targetScaler.Max - targetScaler.Min;
            range(range == 0) = 1;
            Y_scaled = (Y - targetScaler.Min) ./ range;
        end
        
        function Y_raw = unscaleTarget(Y_scaled, targetScaler)
            range = targetScaler.Max - targetScaler.Min;
            range(range == 0) = 1;
            Y_raw = Y_scaled .* range + targetScaler.Min;
        end
        
        function [X_seq, validIdx] = formatForCNNLSTM(X_scaled, sequenceLength)
            % Single source of truth for sequence formatting
            if nargin < 2
                sequenceLength = 30;
            end
            
            numSamples = size(X_scaled, 1) - sequenceLength + 1;
            if numSamples <= 0
                error('Not enough data for sequence length %d. Rows: %d', sequenceLength, size(X_scaled, 1));
            end
            
            X_seq = cell(numSamples, 1);
            for i = 1:numSamples
                X_seq{i} = X_scaled(i:i+sequenceLength-1, :)';
            end
            
            validIdx = sequenceLength:size(X_scaled, 1);
        end
        
        function preds = predictEnsemble(models, X_scaled, targetScaler, scaler, featureList)
            % Real Ensemble Prediction (CNN-LSTM + ARIMAX)
            % Both sub-model outputs are brought to the SAME raw price space
            % before applying ensemble weights.
            %
            % Failure policy: the ARIMAX sub-model is a required component. A
            % missing model, a stub placeholder, or a failing forecast is a
            % genuine defect and is surfaced to the caller. It is never silently
            % replaced by CNN output, which would quietly inflate the CNN
            % weight and corrupt the ensemble blend.
            
            % 0. Preconditions (fail fast, before any expensive inference)
            if ~isfield(models, 'CNN') || isempty(models.CNN)
                error('predictEnsemble:CNNMISSING', ...
                    'predictEnsemble: CNN-LSTM model missing from the model bundle.');
            end
            if ~isfield(models, 'ARIMA') || isempty(models.ARIMA)
                error('predictEnsemble:ARIMAMissing', ...
                    'predictEnsemble: ARIMAX model missing from the model bundle.');
            end
            if isstruct(models.ARIMA)
                error('predictEnsemble:ARIMAMissing', ...
                    'predictEnsemble: ARIMAX model is a stub placeholder (struct), not a fitted ARIMAX model.');
            end
            if nargin < 5 || isempty(featureList)
                error('predictEnsemble:MissingFeatureList', ...
                    'predictEnsemble: Feature list required to align features for ARIMAX.');
            end
            if nargin < 4 || isempty(scaler) || ~isstruct(scaler) || ...
                    ~isfield(scaler, 'Min') || ~isfield(scaler, 'Max')
                error('predictEnsemble:MissingScaler', ...
                    'predictEnsemble: scaler with Min/Max is required to un-scale features for ARIMAX.');
            end
            closeIdx = find(strcmp(featureList, 'Close'), 1);
            sentimentIdx = find(strcmp(featureList, 'Daily_Sentiment'), 1);
            if isempty(closeIdx) || isempty(sentimentIdx)
                error('predictEnsemble:MissingFeatureColumn', ...
                    'predictEnsemble: Close or Daily_Sentiment not found in featureList.');
            end
            if numel(scaler.Min) ~= size(X_scaled, 2) || numel(scaler.Max) ~= size(X_scaled, 2)
                error('predictEnsemble:ScalerShapeMismatch', ...
                    'predictEnsemble: scaler.Min/Max width (%d) does not match feature count (%d).', ...
                    numel(scaler.Min), size(X_scaled, 2));
            end
            
            % 1. CNN-LSTM Prediction
            [X_seq, ~] = PipelineDataProcessor.formatForCNNLSTM(X_scaled);
            cnnPredsScaled = double(predict(models.CNN, X_seq));
            cnnPreds = PipelineDataProcessor.unscaleTarget(cnnPredsScaled, targetScaler);
            
            % 2. ARIMAX Prediction
            % ARIMAX model was trained on raw (unscaled) Close as response
            % with Daily_Sentiment as exogenous input.
            % Therefore forecast() requires raw-space Y0 and XF.
            
            % Un-scale features from X_scaled back to raw space
            % scaler.Min and scaler.Max are per-feature vectors
            range = scaler.Max - scaler.Min;
            range(range == 0) = 1;
            X_raw = X_scaled .* range + scaler.Min;
            
            % For ARIMAX, produce one-step-ahead forecasts matching CNN-LSTM output count.
            % Rolling forecast: for each position t, forecast t+1 using Y0 from t,t-1 and XF at t+1.
            % This avoids the divergence that occurs when forecasting thousands of steps from a single Y0.
            
            arimaPreds = zeros(size(cnnPreds));
            numSamples = length(cnnPreds);
            
            % For each sample, compute 1-step-ahead ARIMAX forecast.
            % Forecasting errors are deliberately left unguarded so that they
            % propagate to the caller instead of being masked.
            for i = 1:numSamples
                % Y0: last 2 observed Close values before this position
                y0Idx = size(X_scaled,1) - numSamples + i;
                y0Idx = max(min(y0Idx, size(X_raw, 1)), 2);
                y0Raw = X_raw(y0Idx-1:y0Idx, closeIdx);
                
                % XF at forecast time (use forward-filled sentiment)
                xfVal = X_raw(min(y0Idx, size(X_raw,1)), sentimentIdx);
                
                % 1-step forecast in raw price space
                arimaPreds(i) = forecast(models.ARIMA, 1, 'Y0', y0Raw, 'XF', xfVal);
            end
            
            % Ensure column vector
            arimaPreds = arimaPreds(:);
            
            % 3. Integrity gate: both sub-models must be in the same raw price
            % space and produce usable numbers. Non-finite output means the
            % blend is meaningless, so fail loudly instead of blending garbage.
            if any(~isfinite(cnnPreds))
                error('predictEnsemble:NonFiniteCNNOutput', ...
                    'predictEnsemble: CNN-LSTM produced %d non-finite predictions.', sum(~isfinite(cnnPreds)));
            end
            if any(~isfinite(arimaPreds))
                error('predictEnsemble:NonFiniteARIMAXOutput', ...
                    'predictEnsemble: ARIMAX produced %d non-finite forecasts.', sum(~isfinite(arimaPreds)));
            end
            
            % 4. Weighted Combination (both outputs in same raw price space)
            if isfield(models, 'EnsembleWeights') && ~isempty(models.EnsembleWeights)
                w = models.EnsembleWeights;
                if length(w) < 2
                    error('predictEnsemble:InvalidEnsembleWeights', ...
                        'predictEnsemble: EnsembleWeights must have at least 2 elements.');
                end
            else
                w = [0.6, 0.4]; % Default weights
            end
            
            padLen = size(X_scaled, 1) - length(cnnPreds);
            preds = [nan(padLen, 1); (w(1) * cnnPreds + w(2) * arimaPreds)];
        end
        
        function generateDataAuditReport()
            % Generates the DataAuditReport.html for Level 2
            Logger.info('Generating Data Audit Report...');
            
            % 1. Load Data
            [fullData, ~, ~] = PipelineDataProcessor.prepareData([], '1d');
            
            % Prepare HTML Lines
            htmlLines = [
                "<html><head><style>"
                "body { font-family: Arial, sans-serif; background-color: #f4f4f9; padding: 20px; }"
                "h1, h2 { color: #333; }"
                "table { border-collapse: collapse; width: 100%; margin-bottom: 30px; background: white; }"
                "th, td { border: 1px solid #ddd; padding: 10px; text-align: left; }"
                "th { background-color: #2196F3; color: white; }"
                ".pass { color: green; font-weight: bold; }"
                ".fail { color: red; font-weight: bold; }"
                ".warn { color: orange; font-weight: bold; }"
                "</style></head><body>"
                "<h1>Data Audit Report</h1>"
                "<p>This report verifies the structural integrity, alignment, and statistical validity of the dataset prior to model training.</p>"
            ];
            
            % 2. Missing Values Check
            numMissing = sum(ismissing(fullData), 'all');
            missingStatus = "PASS";
            missingClass = "pass";
            if numMissing > 0
                missingStatus = "FAIL";
                missingClass = "fail";
            end
            
            % 3. Duplicate Rows Check
            numDuplicates = size(fullData, 1) - size(unique(fullData), 1);
            dupStatus = "PASS";
            dupClass = "pass";
            if numDuplicates > 0
                dupStatus = "FAIL";
                dupClass = "fail";
            end
            
            % 4. Timestamp Alignment
            dates = fullData.Date;
            expectedDates = (min(dates):caldays(1):max(dates))';
            missingDays = numel(expectedDates) - numel(dates);
            timeStatus = "PASS";
            timeClass = "pass";
            if missingDays > 0
                timeStatus = "WARN";
                timeClass = "warn";
            end
            
            % 5. Data Leakage & Target Alignment
            leakageCount = sum(fullData.Target == fullData.Close);
            leakStatus = "PASS";
            leakClass = "pass";
            if leakageCount > 0
                leakStatus = "WARN";
                leakClass = "warn";
            end
            
            % 6. Tweet Alignment
            tweetVolumeMean = mean(fullData.Tweet_Volume);
            tweetStatus = "PASS";
            tweetClass = "pass";
            if tweetVolumeMean < 10
                tweetStatus = "WARN";
                tweetClass = "warn";
            end
            
            % Summary Table
            htmlLines = [htmlLines; %#ok<AGROW>
                "<h2>Data Integrity Checks</h2>"
                "<table><tr><th>Audit Metric</th><th>Result</th><th>Status</th></tr>"
                "<tr><td>Missing Values</td><td>" + num2str(numMissing) + " missing elements</td><td class='" + missingClass + "'>" + missingStatus + "</td></tr>"
                "<tr><td>Duplicate Rows</td><td>" + num2str(numDuplicates) + " duplicate rows</td><td class='" + dupClass + "'>" + dupStatus + "</td></tr>"
                "<tr><td>Timestamp Alignment</td><td>" + num2str(missingDays) + " missing days in sequence</td><td class='" + timeClass + "'>" + timeStatus + "</td></tr>"
                "<tr><td>Data Leakage (Target == Close)</td><td>" + num2str(leakageCount) + " overlapping values</td><td class='" + leakClass + "'>" + leakStatus + "</td></tr>"
                "<tr><td>Tweet Alignment (Avg Volume)</td><td>" + num2str(tweetVolumeMean, '%.1f') + " tweets/day</td><td class='" + tweetClass + "'>" + tweetStatus + "</td></tr>"
                "</table>"
            ];
            
            % 7. Feature Scaling & Sample Stats
            htmlLines = [htmlLines; %#ok<AGROW>
                "<h2>Feature Scaling Statistics (Raw)</h2>"
                "<table><tr><th>Feature</th><th>Min</th><th>Max</th><th>Mean</th><th>Std Dev</th></tr>"
            ];
            
            numericVars = fullData(:, vartype('numeric'));
            varNames = numericVars.Properties.VariableNames;
            for i = 1:width(numericVars)
                v = numericVars{:, i};
                minV = min(v); maxV = max(v); meanV = mean(v); stdV = std(v);
                htmlLines = [htmlLines; %#ok<AGROW>
                    "<tr><td>" + string(varNames{i}) + "</td>" + ...
                    "<td>" + num2str(minV, '%.4f') + "</td>" + ...
                    "<td>" + num2str(maxV, '%.4f') + "</td>" + ...
                    "<td>" + num2str(meanV, '%.4f') + "</td>" + ...
                    "<td>" + num2str(stdV, '%.4f') + "</td></tr>"
                ];
            end
            
            htmlLines = [htmlLines; %#ok<AGROW>
                "</table>"
                "</body></html>"
            ];
            
            % Write to file
            html = strjoin(htmlLines, newline);
            reportDir = fullfile(pwd, 'reports');
            if ~exist(reportDir, 'dir'), mkdir(reportDir); end
            fid = fopen(fullfile(reportDir, 'DataAuditReport.html'), 'w');
            fprintf(fid, '%s', html);
            fclose(fid);
            
            Logger.success('DataAuditReport.html successfully generated in the reports folder.');
        end
    end
end

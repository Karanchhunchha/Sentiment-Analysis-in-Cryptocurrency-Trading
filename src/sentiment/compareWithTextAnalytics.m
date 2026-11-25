function results = compareWithTextAnalytics(texts)
    % compareWithTextAnalytics Compares Text Analytics Toolbox sentiment
    % scorers against the existing SentinelCrypto scorers on the same texts.
    %
    % Implements the comparison prescribed in the MathWorks review of
    % Challenge Project #239 (Text Analytics Toolbox adoption): the
    % toolbox functions vaderSentimentScores and ratioSentimentScores are
    % computed alongside the project's existing scorers — the VADER score
    % returned by SentimentEngine.analyzeText (Python vaderSentiment bridge
    % with the built-in lexicon fallback) and the trained Naive Bayes / SVM
    % scores — on the SAME sample texts, and an agreement summary is
    % printed.
    %
    % Usage:
    %   results = compareWithTextAnalytics();         % CryptoLin fixture texts
    %   results = compareWithTextAnalytics(myTexts);  % custom string array
    %
    % With no input, the sample texts are the CryptoLin headlines in
    % data/sentiment/cryptolin.csv — the same fixture SentimentEngine
    % trains on and SentimentEvaluationT07 evaluates (columns: text, label).
    %
    % Output: struct with the per-text score vectors (TAVader, TARatio,
    % ExistingVader, ExistingNB, ExistingSVM) and agreement statistics
    % (sign-agreement percentages and Pearson correlations). When ground
    % truth labels are available, accuracy under the pre-specified rule
    % "score > 0 -> Positive" (same rule as SentimentEvaluationT07) is
    % reported for every method.
    %
    % Requires: Text Analytics Toolbox (tokenizedDocument,
    % vaderSentimentScores, ratioSentimentScores).
    
    results = struct();
    
    % --- Resolve sample texts (and labels, when available) ---
    labels = string.empty;
    if nargin < 1 || isempty(texts)
        rootDir = fileparts(fileparts(fileparts(which('compareWithTextAnalytics'))));
        if isempty(rootDir)
            rootDir = pwd;
        end
        dataPath = fullfile(rootDir, 'data', 'sentiment', 'cryptolin.csv');
        if ~exist(dataPath, 'file')
            Logger.warning('CryptoLin dataset not found at %s. Nothing to compare.', dataPath);
            return;
        end
        data = readtable(dataPath);
        texts = string(data.text);
        if ismember('label', data.Properties.VariableNames)
            labels = string(data.label);
        end
    else
        texts = string(texts);
    end
    texts = texts(:);
    n = numel(texts);
    Logger.info('Comparing Text Analytics scorers against existing scorers on %d texts...', n);
    
    % --- Guard: Text Analytics Toolbox must be present ---
    if isempty(which('vaderSentimentScores')) || isempty(which('ratioSentimentScores'))
        Logger.error('Text Analytics Toolbox functions not found (vaderSentimentScores / ratioSentimentScores). Comparison aborted.');
        return;
    end
    
    % --- Text Analytics Toolbox scorers ---
    % VADER is computed on the plain tokenized documents: the algorithm
    % deliberately uses punctuation and capitalization as intensity cues,
    % so the cleaning steps below would remove part of its signal.
    rawDocs = tokenizedDocument(texts);
    % vaderSentimentScores' output shape depends on the release: some
    % return a table with a Compound variable, others return the
    % compound scores directly as a numeric vector (observed on
    % R2026b, where assuming a table crashed this function). Handle
    % both shapes explicitly.
    vaderOut = vaderSentimentScores(rawDocs);
    if istable(vaderOut)
        if ~ismember('Compound', vaderOut.Properties.VariableNames)
            error('compareWithTextAnalytics:UnexpectedVaderOutput', ...
                'vaderSentimentScores output has no ''Compound'' variable. Found: %s', ...
                strjoin(vaderOut.Properties.VariableNames, ', '));
        end
        taVader = vaderOut.Compound;
    else
        taVader = double(vaderOut(:));
    end
    
    % Ratio scorer on the preprocessed documents (pipeline prescribed in
    % the review: tokenizedDocument, erasePunctuation, removeStopWords,
    % normalizeWords).
    cleanDocs = tokenizedDocument(texts);
    cleanDocs = erasePunctuation(cleanDocs);
    cleanDocs = removeStopWords(cleanDocs);
    cleanDocs = normalizeWords(cleanDocs);
    ratioOut = ratioSentimentScores(cleanDocs);
    if istable(ratioOut)
        if ~ismember('SentimentScore', ratioOut.Properties.VariableNames)
            error('compareWithTextAnalytics:UnexpectedRatioOutput', ...
                'ratioSentimentScores output has no ''SentimentScore'' variable. Found: %s', ...
                strjoin(ratioOut.Properties.VariableNames, ', '));
        end
        taRatio = ratioOut.SentimentScore;
    else
        taRatio = double(ratioOut(:));
    end
    
    % --- Existing scorers (SentimentEngine.analyzeText) ---
    engine = SentimentEngine();
    existingNB = nan(n, 1);
    existingVader = nan(n, 1);
    existingSVM = nan(n, 1);
    scorerFailed = false;
    for i = 1:n
        try
            [nbScore, vaderScore, svmScore] = engine.analyzeText(texts(i));
            existingNB(i) = nbScore;
            existingVader(i) = vaderScore;
            existingSVM(i) = svmScore;
        catch
            scorerFailed = true; % Leave NaN; reported in the summary below
        end
    end
    if scorerFailed
        Logger.warning('SentimentEngine.analyzeText failed for one or more texts; those entries are NaN and excluded from agreement statistics.');
    end
    
    % --- Agreement statistics ---
    results.Texts = texts;
    results.TAVader = taVader;
    results.TARatio = taRatio;
    results.ExistingVader = existingVader;
    results.ExistingNB = existingNB;
    results.ExistingSVM = existingSVM;
    
    results.SignAgreement.TAVaderVsExistingVader = signAgreement(taVader, existingVader);
    results.SignAgreement.TARatioVsExistingVader = signAgreement(taRatio, existingVader);
    results.SignAgreement.TAVaderVsTARatio = signAgreement(taVader, taRatio);
    results.Correlation.TAVaderVsExistingVader = safeCorr(taVader, existingVader);
    results.Correlation.TARatioVsExistingVader = safeCorr(taRatio, existingVader);
    results.Correlation.TAVaderVsTARatio = safeCorr(taVader, taRatio);
    
    % --- Accuracy vs ground truth, when labels are available ---
    hasLabels = numel(labels) == n;
    if hasLabels
        results.Labels = labels;
        truthPositive = labels == "Positive";
        results.Accuracy.TAVader = binaryAccuracy(taVader, truthPositive);
        results.Accuracy.TARatio = binaryAccuracy(taRatio, truthPositive);
        results.Accuracy.ExistingVader = binaryAccuracy(existingVader, truthPositive);
        results.Accuracy.ExistingNB = binaryAccuracy(existingNB, truthPositive);
        results.Accuracy.ExistingSVM = binaryAccuracy(existingSVM, truthPositive);
    end
    
    % --- Printed agreement summary ---
    fprintf('\n======================================================\n');
    fprintf('     TEXT ANALYTICS vs EXISTING SCORERS (%d texts)     \n', n);
    fprintf('======================================================\n');
    fprintf('Sign agreement  TA-VADER  vs Existing VADER: %6.1f%%\n', results.SignAgreement.TAVaderVsExistingVader);
    fprintf('Sign agreement  TA-Ratio  vs Existing VADER: %6.1f%%\n', results.SignAgreement.TARatioVsExistingVader);
    fprintf('Sign agreement  TA-VADER  vs TA-Ratio:       %6.1f%%\n', results.SignAgreement.TAVaderVsTARatio);
    fprintf('Correlation     TA-VADER  vs Existing VADER: %6.3f\n', results.Correlation.TAVaderVsExistingVader);
    fprintf('Correlation     TA-Ratio  vs Existing VADER: %6.3f\n', results.Correlation.TARatioVsExistingVader);
    fprintf('Correlation     TA-VADER  vs TA-Ratio:       %6.3f\n', results.Correlation.TAVaderVsTARatio);
    if hasLabels
        fprintf('Accuracy (score > 0 -> Positive):\n');
        fprintf('  TA-VADER: %.1f%%   TA-Ratio: %.1f%%   Existing VADER: %.1f%%   NB: %.1f%%   SVM: %.1f%%\n', ...
            results.Accuracy.TAVader, results.Accuracy.TARatio, results.Accuracy.ExistingVader, ...
            results.Accuracy.ExistingNB, results.Accuracy.ExistingSVM);
    end
    fprintf('======================================================\n');
    
    Logger.success('Text Analytics comparison complete.');
end

function pct = signAgreement(a, b)
    % Percentage of entries whose signs agree, ignoring NaN pairs
    valid = ~isnan(a) & ~isnan(b);
    if ~any(valid)
        pct = NaN;
        return;
    end
    pct = 100 * mean(sign(a(valid)) == sign(b(valid)));
end

function r = safeCorr(a, b)
    % Pearson correlation over non-NaN pairs; NaN when undefined
    valid = ~isnan(a) & ~isnan(b);
    if sum(valid) < 3 || std(a(valid)) == 0 || std(b(valid)) == 0
        r = NaN;
        return;
    end
    r = corr(a(valid), b(valid));
end

function acc = binaryAccuracy(scores, truthPositive)
    % Accuracy of the pre-specified rule "score > 0 -> Positive"
    valid = ~isnan(scores);
    if ~any(valid)
        acc = NaN;
        return;
    end
    acc = 100 * mean((scores(valid) > 0) == truthPositive(valid));
end

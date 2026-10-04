classdef SentimentEvaluationT07 < handle
    % SentimentEvaluationT07 Leave-One-Out comparison of sentiment methods
    % on the CryptoLin human-annotated cryptocurrency NEWS/TEXT dataset.
    %
    % This is a dedicated evaluation harness. It does NOT modify locked T06 components.
    
    properties
        Data
        Labels            % categorical array: Positive/Negative
        Texts             % string array
        DuplicateGroups   % cell array of same-text record indices
        VaderAvailable    % boolean
        VaderAnalyzer     % Python VADER instance
        CryptoLinPath     % Instance property initialized in constructor
    end
    
    properties (Constant)
        BinaryThreshold = 0  % Pre-specified: score > 0 = Positive
    end
    
    methods
        function obj = SentimentEvaluationT07()
            % Hardcode absolute path relative to project for now to unblock
            obj.CryptoLinPath = 'D:\Sentiment Analysis in Cryptocurrency Trading\data\sentiment\cryptolin.csv';
            
            obj.loadAndValidateData();
            obj.checkVaderAvailability();
            obj.identifyDuplicates();
        end
        
        function loadAndValidateData(obj)
            if ~exist(obj.CryptoLinPath, 'file')
                error('CryptoLin dataset not found: %s', obj.CryptoLinPath);
            end
            obj.Data = readtable(obj.CryptoLinPath);
            
            if width(obj.Data) < 2
                error('CryptoLin CSV must have at least 2 columns: text, label');
            end
            
            obj.Texts = string(obj.Data.text);
            obj.Labels = categorical(string(obj.Data.label));
            
            uniqueLabels = unique(string(obj.Labels));
            expectedLabels = sort(string({'Negative', 'Positive'}));
            if ~isequal(uniqueLabels(:), expectedLabels(:))
                error('CryptoLin labels must be exactly {Positive, Negative}. Found: %s', strjoin(uniqueLabels, ', '));
            end
        end
        
        function checkVaderAvailability(obj)
            obj.VaderAvailable = false;
            try
                py.importlib.import_module('vaderSentiment.vaderSentiment');
                vader = py.vaderSentiment.vaderSentiment.SentimentIntensityAnalyzer();
                obj.VaderAnalyzer = vader;
                obj.VaderAvailable = true;
            catch
                obj.VaderAvailable = false;
            end
        end
        
        function identifyDuplicates(obj)
            obj.DuplicateGroups = {};
            [uniqueTexts, ~, idx] = unique(obj.Texts);
            dupCounts = accumarray(idx, 1);
            dupTexts = uniqueTexts(dupCounts > 1);
            
            for i = 1:numel(dupTexts)
                text = dupTexts(i);
                groupIdx = find(obj.Texts == text);
                if numel(groupIdx) > 1
                    obj.DuplicateGroups{end+1} = groupIdx;
                end
            end
        end
        
        function results = runLOOCV(obj)
            n = numel(obj.Texts);
            
            categories = ["Negative", "Positive", "Unavailable"];
            vaderPreds = categorical(repmat("Unavailable", n, 1), categories);
            vaderScores = zeros(n, 1);
            lexiconPreds = categorical(repmat("Unavailable", n, 1), categories);
            lexiconScores = zeros(n, 1);
            nbPreds = categorical(repmat("Unavailable", n, 1), categories);
            svmPreds = categorical(repmat("Unavailable", n, 1), categories);
            
            for i = 1:n
                trainIdx = setdiff(1:n, i);
                
                % VADER (no training)
                if obj.VaderAvailable
                    vScore = obj.vaderScoreSingle(obj.Texts(i));
                    vaderScores(i) = vScore;
                    vaderPreds(i) = obj.binaryFromScore(vScore);
                else
                    vaderPreds(i) = categorical({'Unavailable'}, categories);
                end
                
                % Lexicon/Ratio (no training)
                lScore = obj.lexiconScoreSingle(obj.Texts(i));
                lexiconScores(i) = lScore;
                lexiconPreds(i) = obj.binaryFromScore(lScore);
                
                % NB/SVM (train on fold training set only)
                [nbPred, svmPred] = obj.mlPredictSingle(obj.Texts(i), trainIdx);
                nbPreds(i) = categorical({char(nbPred)}, categories);
                svmPreds(i) = categorical({char(svmPred)}, categories);
            end
            
            results.Labels = obj.Labels;
            results.VaderPred = vaderPreds;
            results.VaderScore = vaderScores;
            results.LexiconPred = lexiconPreds;
            results.LexiconScore = lexiconScores;
            results.NBPred = nbPreds;
            results.SVMPred = svmPreds;
            
            % Aggregate metrics
            results.N = n;
            results.NPositive = double(sum(obj.Labels == 'Positive'));
            results.NNegative = double(sum(obj.Labels == 'Negative'));
            
            vaderMetrics = obj.computeMetrics(vaderPreds, obj.Labels);
            lexiconMetrics = obj.computeMetrics(lexiconPreds, obj.Labels);
            nbMetrics = obj.computeMetrics(nbPreds, obj.Labels);
            svmMetrics = obj.computeMetrics(svmPreds, obj.Labels);
            
            results.VaderAccuracy = vaderMetrics.Accuracy;
            results.VaderPrecision = vaderMetrics.Precision;
            results.VaderRecall = vaderMetrics.Recall;
            results.VaderF1 = vaderMetrics.F1;
            results.VaderConfusionMatrix = vaderMetrics.ConfusionMatrix;
            
            results.LexiconAccuracy = lexiconMetrics.Accuracy;
            results.LexiconPrecision = lexiconMetrics.Precision;
            results.LexiconRecall = lexiconMetrics.Recall;
            results.LexiconF1 = lexiconMetrics.F1;
            results.LexiconConfusionMatrix = lexiconMetrics.ConfusionMatrix;
            
            results.NBAccuracy = nbMetrics.Accuracy;
            results.NBPrecision = nbMetrics.Precision;
            results.NBRecall = nbMetrics.Recall;
            results.NBF1 = nbMetrics.F1;
            results.NBConfusionMatrix = nbMetrics.ConfusionMatrix;
            
            results.SVMAccuracy = svmMetrics.Accuracy;
            results.SVMPrecision = svmMetrics.Precision;
            results.SVMRecall = svmMetrics.Recall;
            results.SVMF1 = svmMetrics.F1;
            results.SVMConfusionMatrix = svmMetrics.ConfusionMatrix;
            
            % Compute Sign Agreement (using score vs label)
            numericLabels = double(obj.Labels == 'Positive') * 2 - 1;
            results.VaderSignAgreement = (sum(sign(vaderScores) == numericLabels) / n) * 100;
            results.LexiconSignAgreement = (sum(sign(lexiconScores) == numericLabels) / n) * 100;
            
            % Continuous score statistics
            results.VaderMean = mean(vaderScores);
            results.VaderStd = std(vaderScores);
            results.VaderMin = min(vaderScores);
            results.VaderMax = max(vaderScores);
            
            results.LexiconMean = mean(lexiconScores);
            results.LexiconStd = std(lexiconScores);
            results.LexiconMin = min(lexiconScores);
            results.LexiconMax = max(lexiconScores);
        end
        
        function [nbPred, svmPred] = mlPredictSingle(obj, testText, trainIdx)
            trainTexts = obj.Texts(trainIdx);
            trainLabels = obj.Labels(trainIdx);
            
            nbPred = categorical({'Unavailable'}, {'Negative', 'Positive', 'Unavailable'});
            svmPred = categorical({'Unavailable'}, {'Negative', 'Positive', 'Unavailable'});
            
            try
                docs = tokenizedDocument(trainTexts);
                bag = bagOfWords(docs);
                testDocs = tokenizedDocument(testText);
                X_train = full(encode(bag, docs));
                X_test = full(encode(bag, testDocs));
                
                rng(42);
                nbModel = fitcnb(X_train, trainLabels, 'DistributionNames', 'mn', ...
                    'ClassNames', categorical({'Negative', 'Positive'}));
                svmModelRaw = fitcsvm(X_train, trainLabels, 'KernelFunction', 'linear', ...
                    'Standardize', true, 'ClassNames', categorical({'Negative', 'Positive'}));
                svmModel = fitSVMPosterior(svmModelRaw);
                
                [~, nbPost] = predict(nbModel, X_test);
                [~, svmPost] = predict(svmModel, X_test);
                
                if nbPost(1, 2) >= 0.5
                    nbPred = categorical({'Positive'});
                else
                    nbPred = categorical({'Negative'});
                end
                
                if svmPost(1, 2) >= 0.5
                    svmPred = categorical({'Positive'});
                else
                    svmPred = categorical({'Negative'});
                end
            catch
                nbPred = categorical({'Unavailable'}, {'Negative', 'Positive', 'Unavailable'});
                svmPred = categorical({'Unavailable'}, {'Negative', 'Positive', 'Unavailable'});
            end
        end
        
        function score = vaderScoreSingle(obj, text)
            score = 0;
            if obj.VaderAvailable
                try
                    pyScores = obj.VaderAnalyzer.polarity_scores(char(text));
                    score = double(pyScores{'compound'});
                catch
                    score = 0;
                end
            end
        end
        
        function score = lexiconScoreSingle(obj, text)
            textLower = lower(char(text));
            tokens = split(textLower);
            posWords = ["up", "buy", "bullish", "moon", "pump", "gain", "profit", "breakout", "good"];
            negWords = ["down", "sell", "bearish", "crash", "dump", "loss", "liquidated", "scam", "drop"];
            posCount = sum(ismember(tokens, posWords));
            negCount = sum(ismember(tokens, negWords));
            total = posCount + negCount;
            if total == 0
                score = 0;
            else
                score = (posCount - negCount) / total;
            end
        end
        
        function pred = binaryFromScore(obj, score)
            if score > obj.BinaryThreshold
                pred = categorical({'Positive'});
            else
                pred = categorical({'Negative'});
            end
        end
        
        function metrics = computeMetrics(obj, predictions, groundTruth)
            unavailableCat = categorical({'Unavailable'});
            validIdx = ~ismember(string(predictions), "Unavailable");
            if sum(validIdx) == 0
                metrics = obj.emptyMetrics();
                return;
            end
            
            validPred = predictions(validIdx);
            validTruth = groundTruth(validIdx);
            
            % Remove 'Unavailable' level if present
            validPred = removecats(validPred, 'Unavailable');
            validTruth = removecats(validTruth, 'Unavailable');
            
            n = numel(validPred);
            
            categories = categorical({'Negative', 'Positive'});
            confMat = confusionmat(validTruth, validPred, 'Order', categories);
            
            tp = confMat(2, 2);
            tn = confMat(1, 1);
            fp = confMat(1, 2);
            fn = confMat(2, 1);
            
            metrics.N = n;
            metrics.NPositive = sum(validTruth == 'Positive');
            metrics.NNegative = sum(validTruth == 'Negative');
            metrics.Accuracy = (tp + tn) / max(sum(confMat(:)), 1);
            metrics.Precision = tp / max(tp + fp, 1);
            metrics.Recall = tp / max(tp + fn, 1);
            metrics.F1 = 2 * (metrics.Precision * metrics.Recall) / max(metrics.Precision + metrics.Recall, 1e-8);
            metrics.ConfusionMatrix = confMat;
        end
        
        function empty = emptyMetrics(obj)
            empty.N = 0;
            empty.NPositive = 0;
            empty.NNegative = 0;
            empty.Accuracy = NaN;
            empty.Precision = NaN;
            empty.Recall = NaN;
            empty.F1 = NaN;
            empty.ConfusionMatrix = [];
        end
    end
end

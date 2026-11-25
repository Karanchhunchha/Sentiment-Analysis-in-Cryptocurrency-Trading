classdef SentimentEvaluationT07 < handle
    % SentimentEvaluationT07 Stratified 10-fold cross-validation
    % comparison of sentiment methods on the CryptoLin human-annotated
    % cryptocurrency NEWS/TEXT dataset.
    %
    % Methodology note (changed during the MathWorks #239 repair,
    % Nov 2026): this harness originally used leave-one-out CV, which
    % had been designed around a 20-record demonstration fixture. On
    % the full 1,741-record corpus, LOOCV with a per-fold SVM fit
    % measured ~90 s per fold (~43 hours for one pass) — infeasible.
    % Stratified 10-fold CV is the standard alternative and preserves
    % the property under test: every record receives exactly one
    % out-of-fold prediction from every method, and each fold's models
    % are trained only on that fold's training records. The SVM is
    % fitclinear (the linear SVM for high-dimensional sparse text;
    % fitcsvm rejects sparse input outright and its dense fit alone
    % measured ~48 s per fold), and its prediction is the classifier's
    % own predicted label.
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
        TokenizedDocs     % tokenizedDocument array, one entry per record
    end
    
    properties (Constant)
        BinaryThreshold = 0  % Pre-specified: score > 0 = Positive
    end
    
    methods
        function obj = SentimentEvaluationT07()
            % Resolve the dataset repo-relatively from this class file's
            % location (same pattern as SentimentEngine.trainMLClassifier):
            % <root>/src/sentiment/SentimentEvaluationT07.m -> <root>.
            rootDir = fileparts(fileparts(fileparts(which('SentimentEvaluationT07'))));
            if isempty(rootDir)
                rootDir = pwd;
            end
            obj.CryptoLinPath = fullfile(rootDir, 'data', 'sentiment', 'cryptolin.csv');
            
            obj.loadAndValidateData();
            obj.checkVaderAvailability();
            obj.identifyDuplicates();
            % Tokenize ONCE here. Tokenization is a per-document
            % operation with no cross-document statistics, so doing it
            % once up front cannot leak held-out information into any
            % fold; the original harness re-tokenized the whole corpus
            % inside every fold.
            obj.TokenizedDocs = tokenizedDocument(obj.Texts);
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
            expectedLabels = sort(["Negative", "Positive"]);
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
        
        function results = runCrossValidation(obj)
            n = numel(obj.Texts);
            
            categories = ["Negative", "Positive", "Unavailable"];
            vaderPreds = categorical(repmat("Unavailable", n, 1), categories);
            vaderScores = zeros(n, 1);
            lexiconPreds = categorical(repmat("Unavailable", n, 1), categories);
            lexiconScores = zeros(n, 1);
            nbPreds = categorical(repmat("Unavailable", n, 1), categories);
            svmPreds = categorical(repmat("Unavailable", n, 1), categories);
            
            % Stratified 10-fold split with a fixed seed: the folds —
            % and therefore every reported number — are deterministic
            % across runs and machines.
            rng(42);
            cp = cvpartition(obj.Labels, 'KFold', 10);
            for f = 1:cp.NumTestSets
                trainIdx = find(training(cp, f));
                testIdx = find(test(cp, f));
                
                % VADER + Lexicon/Ratio (no training) on the held-out fold
                for j = 1:numel(testIdx)
                    i = testIdx(j);
                    if obj.VaderAvailable
                        vScore = obj.vaderScoreSingle(obj.Texts(i));
                        vaderScores(i) = vScore;
                        vaderPreds(i) = obj.binaryFromScore(vScore);
                    end
                    lScore = obj.lexiconScoreSingle(obj.Texts(i));
                    lexiconScores(i) = lScore;
                    lexiconPreds(i) = obj.binaryFromScore(lScore);
                end
                
                % NB/SVM trained on this fold's training records only
                [nbFold, svmFold] = obj.mlPredictFold(testIdx, trainIdx);
                nbPreds(testIdx) = nbFold;
                svmPreds(testIdx) = svmFold;
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
        
        function [nbPreds, svmPreds] = mlPredictFold(obj, testIdx, trainIdx)
            % Trains both ML scorers on the fold's training records and
            % predicts the fold's held-out records in batch.
            trainLabels = obj.Labels(trainIdx);
            cats = {'Negative', 'Positive', 'Unavailable'};
            m = numel(testIdx);
            nbPreds = categorical(repmat({'Unavailable'}, m, 1), cats);
            svmPreds = categorical(repmat({'Unavailable'}, m, 1), cats);
            
            % Vocabulary (bag) is built from the fold's TRAINING
            % documents only — held-out documents never contribute to
            % the vocabulary. Tokenization itself was done once in the
            % constructor (per-document, no cross-document statistics,
            % so no leakage).
            docs = obj.TokenizedDocs(trainIdx);
            bag = bagOfWords(docs);
            X_train = encode(bag, docs);
            X_test = encode(bag, obj.TokenizedDocs(testIdx));

            % Each model is fitted in its OWN try/catch: the two
            % previously shared one, so when the SVM fit failed, the
            % Naive Bayes predictions were silently discarded along
            % with it and every record came back "Unavailable".

            % Naive Bayes (multinomial, sparse counts).
            try
                rng(42);
                nbModel = fitcnb(X_train, trainLabels, 'DistributionNames', 'mn', ...
                    'ClassNames', categorical({'Negative', 'Positive'}));
                [~, nbPost] = predict(nbModel, X_test);
                nbLabels = repmat("Negative", m, 1);
                nbLabels(nbPost(:, 2) >= 0.5) = "Positive";
                nbPreds = categorical(cellstr(nbLabels), cats);
            catch
                % nbPreds stays "Unavailable" for this fold
            end

            % Linear SVM via fitclinear — the SVM implementation for
            % high-dimensional sparse text. (fitcsvm rejects sparse
            % input, and its dense fit + posterior calibration measured
            % ~90 s per single record under leave-one-out.) The
            % prediction is the classifier's own predicted label.
            try
                rng(42);
                svmModel = fitclinear(X_train, trainLabels, 'Learner', 'svm', ...
                    'ClassNames', categorical({'Negative', 'Positive'}));
                svmLabels = predict(svmModel, X_test);
                svmPreds = categorical(cellstr(string(svmLabels)), cats);
            catch
                % svmPreds stays "Unavailable" for this fold
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
        
        function score = lexiconScoreSingle(~, text)
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
        
        function empty = emptyMetrics(~)
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

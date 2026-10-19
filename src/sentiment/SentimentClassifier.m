classdef SentimentClassifier
    properties
        NBModel
        SVMModel
        TrainingBag
    end

    methods
        function obj = SentimentClassifier()
        end

        function obj = train(obj, dataPath)
            if ~exist(dataPath, 'file'), error('Dataset not found: %s', dataPath); end
            data = readtable(dataPath);
            rng(42);
            cv = cvpartition(data.label, 'HoldOut', 0.2);
            trainIdx = training(cv);
            trainData = data(trainIdx, :);

            hasTextAnalytics = ~isempty(which('tokenizedDocument')) && ~isempty(which('bagOfWords'));

            if hasTextAnalytics
                documents = tokenizedDocument(trainData.text);
                obj.TrainingBag = bagOfWords(documents);
                X_train = full(encode(obj.TrainingBag, documents));
            else
                texts = string(trainData.text);
                vocab = unique(lower(split(join(texts))));
                vocab(cellfun(@isempty, vocab)) = [];
                obj.TrainingBag = struct('Vocabulary', vocab, 'NumWords', length(vocab));
                X_train = zeros(length(texts), length(vocab));
                for i = 1:length(texts)
                    words = lower(split(texts(i)));
                    [~, loc] = ismember(words, vocab);
                    loc(loc == 0) = [];
                    X_train(i, loc) = 1;
                end
            end

            y_train = categorical(trainData.label);
            if size(X_train, 1) ~= numel(y_train), error('Alignment Error.'); end
            obj.NBModel = fitcnb(X_train, y_train, 'DistributionNames', 'mn', 'ClassNames', {'Negative', 'Positive'});
            svmModelRaw = fitcsvm(X_train, y_train, 'KernelFunction', 'linear', 'Standardize', true, 'ClassNames', {'Negative', 'Positive'});
            obj.SVMModel = fitSVMPosterior(svmModelRaw);
        end

        function [nbScore, svmScore] = predict(obj, text)
            hasTextAnalytics = ~isempty(which('tokenizedDocument')) && ~(isstruct(obj.TrainingBag));

            if hasTextAnalytics
                docs = tokenizedDocument(text);
                X = full(encode(obj.TrainingBag, docs));
                numWords = obj.TrainingBag.NumWords;
                counts = zeros(1, numWords);
                counts(1:min(size(X, 2), numWords)) = X(1:min(size(X, 2), numWords));
            else
                if isstruct(obj.TrainingBag) && isfield(obj.TrainingBag, 'Vocabulary')
                    vocab = obj.TrainingBag.Vocabulary;
                    numWords = obj.TrainingBag.NumWords;
                elseif isa(obj.TrainingBag, 'bagOfWords')
                    vocab = obj.TrainingBag.Vocabulary;
                    numWords = obj.TrainingBag.NumWords;
                else
                    vocab = string.empty();
                    numWords = 0;
                end
                counts = zeros(1, numWords);
                words = lower(split(string(text)));
                [~, loc] = ismember(words, vocab);
                loc(loc == 0) = [];
                if numWords > 0
                    loc(loc > numWords) = [];
                    counts(loc) = 1;
                end
            end

            if ~isempty(obj.SVMModel)
                [~, svmPosterior] = predict(obj.SVMModel, counts);
                svmScore = 2 * svmPosterior(2) - 1;
            else
                svmScore = 0;
            end
            if ~isempty(obj.NBModel)
                [~, posterior] = predict(obj.NBModel, counts);
                nbScore = 2 * posterior(2) - 1;
            else
                nbScore = 0;
            end
        end

        function metrics = evaluate(obj, testPath)
            testData = readtable(testPath);
            hasTextAnalytics = ~isempty(which('tokenizedDocument')) && ~(isstruct(obj.TrainingBag));

            if hasTextAnalytics
                X_test_raw = full(encode(obj.TrainingBag, tokenizedDocument(testData.text)));
                X_test = zeros(size(X_test_raw, 1), obj.TrainingBag.NumWords);
                X_test(:, 1:min(size(X_test_raw, 2), obj.TrainingBag.NumWords)) = X_test_raw(:, 1:min(size(X_test_raw, 2), obj.TrainingBag.NumWords));
            else
                if isstruct(obj.TrainingBag) && isfield(obj.TrainingBag, 'Vocabulary')
                    vocab = obj.TrainingBag.Vocabulary;
                    numWords = obj.TrainingBag.NumWords;
                else
                    vocab = string.empty();
                    numWords = 0;
                end
                X_test = zeros(length(testData.text), numWords);
                for i = 1:length(testData.text)
                    words = lower(split(string(testData.text(i))));
                    [~, loc] = ismember(words, vocab);
                    loc(loc == 0) = [];
                    if numWords > 0
                        loc(loc > numWords) = [];
                        X_test(i, loc) = 1;
                    end
                end
            end

            y_test = categorical(testData.label);
            y_pred_nb = predict(obj.NBModel, X_test);
            y_pred_svm = predict(obj.SVMModel, X_test);
            metrics.NB = obj.computeMetrics(y_test, y_pred_nb);
            metrics.SVM = obj.computeMetrics(y_test, y_pred_svm);
        end
    end

    methods (Access = private)
        function m = computeMetrics(~, y_test, y_pred)
            categories = {'Negative', 'Positive'};
            y_test = categorical(y_test, categories);
            y_pred = categorical(y_pred, categories);
            confMat = confusionmat(y_test, y_pred, 'Order', categories);
            tp = confMat(2,2); tn = confMat(1,1); fp = confMat(1,2); fn = confMat(2,1);
            m.Accuracy = (tp + tn) / max(sum(confMat(:)), 1);
            m.Precision = tp / max(tp + fp, 1);
            m.Recall = tp / max(tp + fn, 1);
            m.F1 = 2 * (m.Precision * m.Recall) / max(m.Precision + m.Recall, 1e-8);
            m.Support = sum(confMat(:));
        end
    end
end

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
            documents = tokenizedDocument(trainData.text);
            obj.TrainingBag = bagOfWords(documents);
            X_train = full(encode(obj.TrainingBag, documents));
            y_train = categorical(trainData.label);
            if size(X_train, 1) ~= numel(y_train), error('Alignment Error.'); end
            obj.NBModel = fitcnb(X_train, y_train, 'DistributionNames', 'mn', 'ClassNames', {'Negative', 'Positive'});
            svmModelRaw = fitcsvm(X_train, y_train, 'KernelFunction', 'linear', 'Standardize', true, 'ClassNames', {'Negative', 'Positive'});
            obj.SVMModel = fitSVMPosterior(svmModelRaw);
        end
        
        function [nbScore, svmScore] = predict(obj, text)
            docs = tokenizedDocument(text);
            X = full(encode(obj.TrainingBag, docs));
            counts = zeros(1, obj.TrainingBag.NumWords);
            counts(1:min(size(X, 2), obj.TrainingBag.NumWords)) = X(1:min(size(X, 2), obj.TrainingBag.NumWords));
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
            X_test_raw = full(encode(obj.TrainingBag, tokenizedDocument(testData.text)));
            X_test = zeros(size(X_test_raw, 1), obj.TrainingBag.NumWords);
            X_test(:, 1:min(size(X_test_raw, 2), obj.TrainingBag.NumWords)) = X_test_raw(:, 1:min(size(X_test_raw, 2), obj.TrainingBag.NumWords));
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

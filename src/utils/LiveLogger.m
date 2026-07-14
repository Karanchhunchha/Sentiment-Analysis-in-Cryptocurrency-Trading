classdef LiveLogger < handle
    % LiveLogger Records predictions during live mode and verifies them 
    % automatically when subsequent prices arrive. Append-only, never overwrites.
    
    properties
        LogFile
        PendingVerifications % Queue of predictions waiting for T+5 verification
    end
    
    methods
        function obj = LiveLogger()
            % Setup file
            if ~exist('data/logs', 'dir')
                mkdir('data/logs');
            end
            
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            obj.LogFile = sprintf('data/logs/LivePredictionLog_%s.csv', timestamp);
            
            % Write headers
            fid = fopen(obj.LogFile, 'a');
            fprintf(fid, 'Time,CurrentPrice,Prediction,Confidence,SL,TP,OutcomeTime,OutcomePrice,Correct\n');
            fclose(fid);
            
            obj.PendingVerifications = [];
        end
        
        function logPrediction(obj, time, currentPrice, prediction, confidence, sl, tp)
            % Record a new prediction and add it to the pending queue
            
            entry = struct();
            entry.Time = time;
            entry.CurrentPrice = currentPrice;
            entry.Prediction = prediction;
            entry.Confidence = confidence;
            entry.SL = sl;
            entry.TP = tp;
            entry.IsLong = prediction > currentPrice;
            
            if isempty(obj.PendingVerifications)
                obj.PendingVerifications = entry;
            else
                obj.PendingVerifications(end+1) = entry;
            end
        end
        
        function verifyPending(obj, currentTime, currentPrice)
            % Check if any pending predictions have reached their maturity (e.g. 5 minutes)
            
            if isempty(obj.PendingVerifications)
                return;
            end
            
            keepIdx = true(size(obj.PendingVerifications));
            
            for i = 1:length(obj.PendingVerifications)
                entry = obj.PendingVerifications(i);
                
                % Assuming 5 minute interval for now
                timeDiff = minutes(currentTime - entry.Time);
                
                if timeDiff >= 5
                    % Evaluate if correct
                    if entry.IsLong
                        isCorrect = currentPrice > entry.CurrentPrice;
                    else
                        isCorrect = currentPrice < entry.CurrentPrice;
                    end
                    
                    % Write to CSV
                    fid = fopen(obj.LogFile, 'a');
                    fprintf(fid, '%s,%.2f,%.2f,%.2f,%.2f,%.2f,%s,%.2f,%d\n', ...
                        datestr(entry.Time), entry.CurrentPrice, entry.Prediction, ...
                        entry.Confidence, entry.SL, entry.TP, ...
                        datestr(currentTime), currentPrice, isCorrect);
                    fclose(fid);
                    
                    keepIdx(i) = false; % Remove from pending
                end
            end
            
            % Update queue
            obj.PendingVerifications = obj.PendingVerifications(keepIdx);
        end
    end
end

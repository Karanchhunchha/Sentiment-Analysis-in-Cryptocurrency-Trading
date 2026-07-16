classdef ProjectionValidator < handle
    % ProjectionValidator Ensures mathematical and logical validity of projections
    
    methods
        function obj = ProjectionValidator()
        end
        
        function [isValid, reason] = validate(obj, expectedPath, upConf, dnConf, signal, tp, sl, currentPrice)
            isValid = true;
            reason = 'VALID';
            
            if any(isnan(expectedPath)) || any(isnan(upConf)) || any(isnan(dnConf))
                isValid = false;
                reason = 'NaN values detected';
                return;
            end
            
            % Check cone widening
            coneWidth = upConf - dnConf;
            if any(diff(coneWidth) < -0.0001) % Allow tiny floating point tolerance
                isValid = false;
                reason = 'Confidence cone narrows unexpectedly';
                return;
            end
            
            % Check TP/SL logic against signal
            if strcmp(signal, 'BUY')
                if tp <= currentPrice
                    isValid = false;
                    reason = 'BUY TP must be above entry';
                    return;
                end
                if sl >= currentPrice
                    isValid = false;
                    reason = 'BUY SL must be below entry';
                    return;
                end
            elseif strcmp(signal, 'SELL')
                if tp >= currentPrice
                    isValid = false;
                    reason = 'SELL TP must be below entry';
                    return;
                end
                if sl <= currentPrice
                    isValid = false;
                    reason = 'SELL SL must be above entry';
                    return;
                end
            end
            
            % RR > 0
            if abs(currentPrice - sl) < 1e-5
                isValid = false;
                reason = 'SL too close to entry (RR undefined)';
                return;
            end
            
            rr = abs(tp - currentPrice) / abs(currentPrice - sl);
            if rr <= 0
                isValid = false;
                reason = 'RR must be > 0';
                return;
            end
            
            % Institutional Validation: Does the forecast actually hit the required TP?
            if strcmp(signal, 'BUY')
                if max(expectedPath) < tp
                    isValid = false;
                    reason = sprintf('Forecast fails to reach 1:%.1f Target', rr);
                    return;
                end
            elseif strcmp(signal, 'SELL')
                if min(expectedPath) > tp
                    isValid = false;
                    reason = sprintf('Forecast fails to reach 1:%.1f Target', rr);
                    return;
                end
            end
        end
    end
end

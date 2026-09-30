function runB01Tests()
    disp('--- B01 TESTS ---');
    
    % TEST A - GOLDEN SMA
    Close = (1:60)';
    SMA_20 = movmean(Close, [19 0]);
    if abs(SMA_20(51) - 41.5) > 1e-6
        error('TEST A FAILED: SMA20(51) is %f, expected 41.5', SMA_20(51));
    end
    disp('TEST A - GOLDEN SMA: PASSED');
    
    % TEST B & C - FUTURE-ROW INVARIANCE & INDICATOR CAUSALITY
    t = 50;
    dates = datetime(2026,1,1) + days(1:60)';
    df_base = table(dates, (1:60)', (1:60)'+1, (1:60)'-1, (1:60)', rand(60,1)*100, ...
        'VariableNames', {'Date', 'Open', 'High', 'Low', 'Close', 'Volume'});
    
    % 1. Calculate features through time t.
    df_t = df_base(1:t, :);
    feat_t = FeatureEngineer.runAll(df_t);
    
    % 2. Append future observations.
    df_t2 = df_base;
    feat_t2 = FeatureEngineer.runAll(df_t2);
    
    % 3 & 4. Recalculate and compare.
    vars = feat_t.Properties.VariableNames;
    failedVars = {};
    for i = 1:length(vars)
        v = vars{i};
        if isnumeric(feat_t.(v))
            diff = max(abs(feat_t.(v) - feat_t2.(v)(1:t)));
            if diff > 1e-10
                failedVars{end+1} = v;
            end
        end
    end
    
    if ~isempty(failedVars)
        error('TEST B & C FAILED: Features changed based on future data: %s', strjoin(failedVars, ', '));
    end
    disp('TEST B & C - FUTURE-ROW INVARIANCE & INDICATOR CAUSALITY: PASSED');
    
    disp('ALL B01 TESTS PASSED.');
end

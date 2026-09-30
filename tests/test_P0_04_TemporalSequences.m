function runP004Tests()
    disp('--- P0-04 TESTS: TEMPORAL CNN-LSTM SEQUENCES ---');
    
    % TEST A & B - SEQUENCE SHAPE & EXACT ALIGNMENT
    X_raw = (1:100)';
    % Dummy 2 feature matrix
    X = [X_raw, X_raw*2]; 
    
    [X_seq, validIdx] = PipelineDataProcessor.formatForCNNLSTM(X, 30);
    
    if length(X_seq) ~= 71
        error('TEST A FAILED: Expected 71 sequences, got %d', length(X_seq));
    end
    
    if size(X_seq{1}, 2) ~= 30
        error('TEST A FAILED: Expected sequence length 30, got %d', size(X_seq{1}, 2));
    end
    
    if size(X_seq{1}, 1) ~= 2
        error('TEST A FAILED: Expected 2 features, got %d', size(X_seq{1}, 1));
    end
    
    % Check sequence 1 contents exactly
    if any(X_seq{1}(1,:)' ~= (1:30)')
        error('TEST B FAILED: Sequence 1 does not contain X(1:30)');
    end
    
    if validIdx(1) ~= 30
        error('TEST B FAILED: Target idx for Sequence 1 should be 30, got %d', validIdx(1));
    end
    
    disp('TEST A & B - SHAPE & ALIGNMENT: PASSED');
    
    % TEST C & D & E - OVERLAP AND CAUSALITY
    % Sequence 2 should overlap with sequence 1 by 29 elements
    seq1_tail = X_seq{1}(:, 2:30);
    seq2_head = X_seq{2}(:, 1:29);
    
    if any(seq1_tail ~= seq2_head, 'all')
        error('TEST E FAILED: Sequences do not overlap by 29 elements exactly.');
    end
    
    % Causality: modifying X(32) should NOT affect sequence 2 (which ends at 31)
    X2 = X;
    X2(32, :) = [999, 999];
    [X_seq2, validIdx2] = PipelineDataProcessor.formatForCNNLSTM(X2, 30);
    
    if any(X_seq2{2} ~= X_seq{2}, 'all')
        error('TEST C/D FAILED: Future row modification altered an earlier sequence!');
    end
    
    disp('TEST C, D & E - OVERLAP & CAUSALITY: PASSED');
    
    disp('ALL P0-04 TESTS PASSED.');
end

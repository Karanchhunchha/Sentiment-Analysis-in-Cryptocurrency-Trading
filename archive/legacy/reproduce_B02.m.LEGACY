% reproduce_B02.m
% Reproduce the fabricated RSI and EMA in FeatureFusionEngine

disp('--- REPRODUCING B02 DEFECT ---');

% Create dummy historical data
histData = table();
histData.Date = (datetime('today') - days(100) : datetime('today') - days(1))';
histData.Close = (101:200)';
histData.Volume = rand(100, 1) * 1000;

% Initialize Engine
engine = FeatureFusionEngine();
[fusedData, ~] = engine.initializeHistorical(histData);

% Display the fabricated EMA
disp('Fabricated EMA_20 (Close * 0.99):');
disp(head(fusedData(:, {'Close', 'EMA_20'}), 5));

% Display non-deterministic RSI
newCandle = table();
newCandle.Date = datetime('today');
newCandle.Close = 205;
newCandle.Volume = 500;

rng(42); % seed
inc1 = engine.updateIncremental(newCandle);
disp('Incremental Update 1 (RSI):');
disp(inc1.RSI);

rng(43); % diff seed
inc2 = engine.updateIncremental(newCandle);
disp('Incremental Update 2 (Same Input, Diff RSI):');
disp(inc2.RSI);

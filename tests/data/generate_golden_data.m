%#ok<*AGROW>
%#ok<*INUSD>
%#ok<*NASGU>
%#ok<*STOUT>
%#ok<*DATNM>
%#ok<*DATST>
%#ok<*MATCH>
% generate_golden_data.m
% Generates deterministic price data for rigorous mathematical testing.
% Saves to tests/data/golden_data.csv

clc; clear;

% We generate 100 candles.
N = 100;
Date = datetime('today') - days(N:-1:1)';

% Create a deterministic price path (e.g., a simple uptrend with a dip)
Open = linspace(100, 200, N)';
Close = Open + sin(1:N)' * 5; % Add some oscillation
High = max(Open, Close) + 2;
Low = min(Open, Close) - 2;
Volume = 1000 * ones(N, 1);

goldenData = table(Date, Open, High, Low, Close, Volume);

% Ensure output directory exists
if ~exist('tests/data', 'dir')
    mkdir('tests/data');
end

writetable(goldenData, 'tests/data/golden_data.csv');
fprintf('Golden data generated at tests/data/golden_data.csv\n');

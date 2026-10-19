% startup.m
% Automatically configures the MATLAB path for SentinelCrypto

[repoDir, ~, ~] = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(repoDir, 'src')));
addpath(genpath(fullfile(repoDir, 'tests')));

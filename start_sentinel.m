% start_sentinel.m
% Entry point for KCryptoX8 v4.0 Research Workstation

clc;
clear;
close all;

% Setup Paths
addpath(fullfile(pwd, 'src', 'dashboard'));
addpath(fullfile(pwd, 'src', 'database'));
addpath(fullfile(pwd, 'src', 'forecasting'));
addpath(fullfile(pwd, 'src', 'strategy'));
addpath(fullfile(pwd, 'src', 'utils'));

disp('======================================================');
disp('   SentinelCrypto Research Workstation v4.0           ');
disp('======================================================');

% Initialize Logging
Logger.init();
Logger.info('Booting SentinelCrypto Platform...');

% Launch the UI Core
app = App();

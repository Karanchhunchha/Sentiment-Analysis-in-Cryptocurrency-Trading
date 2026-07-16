% quick_forecast_v2.m
% Uses pure technical analysis (ATR momentum + support/resistance) on live data
% to assess TP probability. No ML model required — honest market structure read.

clc;
addpath(genpath('src'));
addpath(genpath('models'));

fprintf('====================================================\n');
fprintf('  SENTINELCRYPTO -- 2H BTC TP ASSESSMENT           \n');
fprintf('  Generated: %s\n', char(datetime('now')));
fprintf('====================================================\n\n');

%% Fetch live 15m candles
fprintf('[1/3] Fetching live 15m candles from Binance...\n');
loader = PriceDataLoader('BTCUSDT', '15m');
liveData = loader.fetchRecentHistory(150);

close_prices = liveData.Close;
high_prices  = liveData.High;
low_prices   = liveData.Low;
n = length(close_prices);

currentPrice = close_prices(end);
fprintf('      Current Price  : $%.2f\n', currentPrice);
fprintf('      Candles loaded : %d (15m bars)\n\n', n);

%% Build indicators
fprintf('[2/3] Computing indicators...\n');

% ATR 14
true_ranges = max([high_prices(2:end) - low_prices(2:end), ...
                   abs(high_prices(2:end) - close_prices(1:end-1)), ...
                   abs(low_prices(2:end)  - close_prices(1:end-1))], [], 2);
atr14 = mean(true_ranges(end-13:end));

% EMAs
a20 = 2/(20+1); ema20 = zeros(n,1); ema20(1) = close_prices(1);
a50 = 2/(50+1); ema50 = zeros(n,1); ema50(1) = close_prices(1);
for i = 2:n
    ema20(i) = close_prices(i)*a20 + ema20(i-1)*(1-a20);
    ema50(i) = close_prices(i)*a50 + ema50(i-1)*(1-a50);
end

% RSI 14
delta = diff(close_prices);
gains = max(delta,0); losses = abs(min(delta,0));
avgGain = mean(gains(end-13:end)); avgLoss = mean(losses(end-13:end));
rsi = 100 - (100 / (1 + avgGain/max(avgLoss,1e-8)));

% Bollinger Bands
sma20 = mean(close_prices(end-19:end));
std20 = std(close_prices(end-19:end));
bb_upper = sma20 + 2*std20;
bb_lower = sma20 - 2*std20;

% Recent momentum (avg of last 4 candles = 1 hour trend)
mom_4  = mean(diff(close_prices(end-4:end)));   % 1h momentum per bar
mom_8  = mean(diff(close_prices(end-8:end)));   % 2h momentum per bar

% Volume trend
vol_recent = mean(liveData.Volume(end-5:end));
vol_avg    = mean(liveData.Volume(end-20:end));
vol_ratio  = vol_recent / vol_avg;

fprintf('      EMA20      : $%.2f | EMA50: $%.2f\n', ema20(end), ema50(end));
fprintf('      RSI(14)    : %.1f\n', rsi);
fprintf('      ATR(14)    : $%.2f\n', atr14);
fprintf('      BB Upper   : $%.2f | BB Lower: $%.2f\n', bb_upper, bb_lower);
fprintf('      1h Momentum: %+.2f per bar | 2h Momentum: %+.2f per bar\n', mom_4, mom_8);
fprintf('      Volume Ratio (recent/avg): %.2fx\n\n', vol_ratio);

%% Chart levels from screenshot
tp1 = 64802;
tp2 = 64996;

gap_tp1_pct = (tp1 - currentPrice) / currentPrice * 100;
gap_tp2_pct = (tp2 - currentPrice) / currentPrice * 100;
gap_tp1_atr = (tp1 - currentPrice) / atr14;
gap_tp2_atr = (tp2 - currentPrice) / atr14;

fprintf('[3/3] TP Analysis...\n\n');
fprintf('  Current Price : $%.2f\n', currentPrice);
fprintf('  TP1 ($64,802) : %+.2f%% away | %.2f ATRs to cover\n', gap_tp1_pct, gap_tp1_atr);
fprintf('  TP2 ($64,996) : %+.2f%% away | %.2f ATRs to cover\n', gap_tp2_pct, gap_tp2_atr);

%% Momentum-based 2h path
horizons = 8;
prices_bull = zeros(1, horizons);  % optimistic: use recent 1h momentum
prices_base = zeros(1, horizons);  % base: use decaying momentum
prices_bear = zeros(1, horizons);  % pessimistic: momentum fades entirely

for h = 1:horizons
    decay = 0.80^h;
    prices_bull(h) = currentPrice + mom_4 * h;
    prices_base(h) = currentPrice + mom_4 * sum(0.85.^(1:h));
    prices_bear(h) = currentPrice + mom_8 * sum(0.60.^(1:h));
end

fprintf('\n%-7s | %-12s | %-12s | %-12s\n', 'T+', 'Bear($)', 'Base($)', 'Bull($)');
fprintf('%s\n', repmat('-', 1, 50));
for h = 1:horizons
    fprintf('T+%3dm  | $%10.2f | $%10.2f | $%10.2f\n', h*15, prices_bear(h), prices_base(h), prices_bull(h));
end

%% Verdict
tp1_hit_bull = any(prices_bull >= tp1);
tp1_hit_base = any(prices_base >= tp1);
tp2_hit_bull = any(prices_bull >= tp2);
tp2_hit_base = any(prices_base >= tp2);

% Determine overall bias
if ema20(end) > ema50(end) && rsi > 50 && mom_4 > 0
    bias = 'BULLISH';
    bias_icon = '📈';
elseif ema20(end) < ema50(end) || rsi < 45 || mom_4 < 0
    bias = 'BEARISH';
    bias_icon = '📉';
else
    bias = 'NEUTRAL';
    bias_icon = '➡️';
end

fprintf('\n====================================================\n');
fprintf('  FINAL VERDICT\n');
fprintf('====================================================\n');
fprintf('  Bias        : %s %s\n', bias_icon, bias);
fprintf('  EMA Cross   : %s\n', ternary(ema20(end)>ema50(end), 'EMA20 > EMA50 (bullish)', 'EMA20 < EMA50 (bearish)'));
fprintf('  RSI         : %.1f  %s\n', rsi, ternary(rsi>55,'(overbought risk)',ternary(rsi<45,'(oversold, bounce likely)','(neutral)')));
fprintf('  Price vs BB : %s\n', ternary(currentPrice > bb_upper, 'Above BB Upper (overextended)', ternary(currentPrice < bb_lower, 'Below BB Lower (bounce setup)', 'Inside bands (normal)')));
fprintf('  Volume      : %s\n', ternary(vol_ratio > 1.2, 'ABOVE avg (conviction)', ternary(vol_ratio < 0.8, 'BELOW avg (weak move)', 'Normal')));
fprintf('\n--- TP PROBABILITY ASSESSMENT ---\n');
fprintf('  TP1 $64,802 (+%.2f%%, %.2f ATR):\n', gap_tp1_pct, gap_tp1_atr);
fprintf('    Bull scenario : %s\n', ternary(tp1_hit_bull, '✅ Hit in 2h', '❌ Not reached'));
fprintf('    Base scenario : %s\n', ternary(tp1_hit_base, '✅ Hit in 2h', '❌ Not reached'));
fprintf('  TP2 $64,996 (+%.2f%%, %.2f ATR):\n', gap_tp2_pct, gap_tp2_atr);
fprintf('    Bull scenario : %s\n', ternary(tp2_hit_bull, '✅ Hit in 2h', '❌ Not reached'));
fprintf('    Base scenario : %s\n', ternary(tp2_hit_base, '✅ Hit in 2h', '❌ Not reached'));
fprintf('====================================================\n');
fprintf('  ⚠ Not financial advice. Backtest model only.\n');
fprintf('====================================================\n');

function r = ternary(cond, a, b)
    if cond; r = a; else; r = b; end
end

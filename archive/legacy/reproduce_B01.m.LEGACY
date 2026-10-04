Close = (1:60)';
SMA_20 = movmean(Close, 20);
expected = movmean(Close, [19 0]);
fprintf('Current SMA20(51): %f\n', SMA_20(51));
fprintf('Causal Expected SMA20(51): %f\n', expected(51));

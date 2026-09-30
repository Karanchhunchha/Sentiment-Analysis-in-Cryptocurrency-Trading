# B02 Evidence: Fabricated Feature Generation Remediation

## Original Defect

The MathWorks reviewer identified that `FeatureFusionEngine.m` fabricated RSI and EMA values rather than computing them from actual market data:

- **Line 30**: `fusedData.RSI = rand(height(fusedData), 1) * 100;` — RSI was populated with uniformly distributed random values between 0 and 100.
- **Line 31**: `fusedData.EMA_20 = fusedData.Close .* 0.99;` — EMA was a fixed 1% discount of Close price, not an exponential moving average.
- **Line 57**: `newRSI = 50 + randn()*5;` — Incremental RSI was a random Gaussian draw around 50, with no connection to price history.

This meant repeated identical inputs would produce different RSI values, and EMA had no relationship to the historical price series.

## Affected File

`src/feature_engineering/FeatureFusionEngine.m`
- `initializeHistorical()` — Lines 29–38 (pre-fix)
- `updateIncremental()` — Lines 55–61 (pre-fix)

## Reproduction (Actual MATLAB R2026b Execution)

Command: `"C:\Program Files\MATLAB\R2026b\bin\matlab.exe" -batch "run('reproduce_B02.m')"`

Output confirmed the defects:
```
Fabricated EMA_20 (Close * 0.99):
    Close    EMA_20
    _____    ______
     101      99.99
     102     100.98
     ...

Incremental Update 1 (RSI):  47.3088
Incremental Update 2 (Same Input, Diff RSI):  44.0898
```

Same input → different RSI values on every call. EMA was clearly just `Close * 0.99` with no recurrence.

## Implementation

**EMA_20 (`initializeHistorical`)**
Replaced `Close * 0.99` with the standard EMA recurrence using `alpha = 2/(20+1)`:
```matlab
fusedData.EMA_20(1) = fusedData.Close(1);
alpha = 2 / (20 + 1);
for i = 2:n
    fusedData.EMA_20(i) = (fusedData.Close(i) * alpha) + (fusedData.EMA_20(i-1) * (1 - alpha));
end
```

**RSI (`initializeHistorical`)**
Replaced `rand(...) * 100` with Wilder's smoothing RSI (14-period):
```matlab
% Seed with simple mean for first period
avgGain(period+1) = mean(gains(2:period+1));
avgLoss(period+1) = mean(losses(2:period+1));
% Wilder's smoothing for subsequent periods
for i = period+2:n
    avgGain(i) = (avgGain(i-1) * (period-1) + gains(i)) / period;
    avgLoss(i) = (avgLoss(i-1) * (period-1) + losses(i)) / period;
end
rs = avgGain ./ max(avgLoss, 1e-8);
fusedData.RSI = 100 - (100 ./ (1 + rs));
```

**Incremental RSI (`updateIncremental`)**
Replaced `50 + randn()*5` with a stateful Wilder's smoothing update using stored `LastAvgGain`/`LastAvgLoss`:
```matlab
diffPrice = currentPrice - obj.LastClose;
gain = max(0, diffPrice);
loss = max(0, -diffPrice);
newAvgGain = (obj.LastAvgGain * (period - 1) + gain) / period;
newAvgLoss = (obj.LastAvgLoss * (period - 1) + loss) / period;
rs = newAvgGain / max(newAvgLoss, 1e-8);
newRSI = 100 - (100 / (1 + rs));
```

New properties added: `LastAvgGain`, `LastAvgLoss`.

## Targeted B02 Tests (Actually Executed in MATLAB R2026b)

**Command**: `"C:\Program Files\MATLAB\R2026b\bin\matlab.exe" -batch "run('tests/test_B02_FabricatedFeatures.m')"`

All 7 tests in `tests/test_B02_FabricatedFeatures.m` PASSED:

| Test | Description | Result |
|------|-------------|--------|
| A — Determinism | Same input → same RSI/EMA, regardless of `rng` state | PASSED |
| B — RSI Correctness | Wilder's RSI matches independent reference calculation | PASSED |
| C — EMA Correctness | EMA series matches independent reference calculation | PASSED |
| D — Incremental Equivalence | `initializeHistorical(history[:-1])` + `updateIncremental(last row)` == `initializeHistorical(full history)` | PASSED |
| E — No Future-Data Dependence | Altering a future price leaves past features identical | PASSED |
| F — Repeated Updates | Identical repeated incremental calls produce identical results | PASSED |
| G — Latency | Average `updateIncremental` latency: **0.513 ms** (< 50 ms target) | PASSED |

## Latency Measurement

- Dataset: 100-period synthetic random-walk price series
- Warmup: 10 iterations
- Measurement: 1000 iterations of `updateIncremental`
- Method: MATLAB `tic`/`toc`
- **Observed**: 0.513 ms average per incremental update
- **Target**: < 50 ms
- **Result**: Requirement satisfied

## Forensic Search

**Command** (production source tree only):
```powershell
Select-String -Pattern "rand\(|randn\(|rng\(|Close\s*\*\s*0\.99" -Path src\*\*.m, src\*\*\*.m
```

**Result**: Zero hits in `src/feature_engineering/`. The two remaining hits in `src/strategy/PortfolioSimulator.m` are:
1. Line 151: Fallback simulated price path when live Binance API call fails — intentional, not a feature engine defect.
2. Line 176: Monte Carlo portfolio weight sampling for MPT efficient frontier — correct and intentional use of randomness.

Neither is in the predictive feature-generation path. B02 forensic audit passes.

## Regression Test Suite (Fully Executed in MATLAB R2026b)

**Command**: `"C:\Program Files\MATLAB\R2026b\bin\matlab.exe" -batch "results = runtests('tests', 'IncludeSubfolders', true); if ~all([results.Passed]), exit(1); end"`

| Test Group | Result |
|------------|--------|
| test_B02_FabricatedFeatures (7 tests) | ALL PASSED |
| test_Latency (2 tests) | ALL PASSED |
| test_DataLoader (2 tests) | ALL PASSED |
| test_FeatureFusionEngine (3 tests) | ALL PASSED |
| test_Indicators (4 tests) | ALL PASSED |
| test_RiskEngine (3 tests) | ALL PASSED |
| test_SentimentEngine (4 tests) | ALL PASSED |

**Total: 25 passed, 0 failed, 0 incomplete. Exit status: 0.**

## Final Conclusion

Fabricated RSI (`rand`) and EMA (`Close*0.99`) have been completely removed from the feature-generation production path. `FeatureFusionEngine` now computes genuine, stateful, deterministic RSI and EMA values using mathematically correct methods (Wilder's smoothing and standard EMA recurrence). Incremental updates are consistent with full historical initialization. No random or fabricated values remain in the predictive feature path.

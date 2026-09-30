# B01 Evidence: Look-Ahead Bias Remediation

## Original Defect
The MathWorks reviewer identified that `movmean`, `movstd`, `movmin`, `movmax`, and `movsum` were being used in `IndicatorEngine.m` and `FeatureEngineer.m` with default centered windows (e.g., `movmean(closeP, 20)`). This implies that future data points were inadvertently used to compute features at time `t`, leading to look-ahead bias (data leakage). 
For `Close = 1:60`, `movmean(Close, 20)` at observation 51 yields `50.5` because it centers the 20-period window, taking observations up to 60.

## Reproduction
A reproduction script `reproduce_B01.m` was written to confirm the mathematical behavior:
```matlab
Close = (1:60)';
SMA_20 = movmean(Close, 20);
expected = movmean(Close, [19 0]);
```
- Current SMA20(51): 50.5
- Causal Expected SMA20(51): 41.5

## Affected Files/Functions
1. `src/indicators/IndicatorEngine.m`:
   - `SMA_20`, `SMA_50`
   - `Volatility_20`, `std20` (Bollinger Bands)
   - `avgGain`, `avgLoss` (RSI calculation)
2. `src/data/FeatureEngineer.m`:
   - `SMA_20`, `SMA_50`, `SMA_200`
   - `VWAP`
   - `avgGain`, `avgLoss` (RSI)
   - `ATR`
   - `BB_Upper`, `BB_Lower`
   - `Rolling_Vol`
   - `Support`, `Resistance`
   - `Buy_Liquidity`, `Sell_Liquidity`

## Implementation
All instances of non-causal centered rolling operations were explicitly converted to causal trailing windows.
Example: `movmean(df.Close, 20)` became `movmean(df.Close, [19 0])`.
Variables like `period` were safely cast as `[period-1 0]`.

## Targeted Tests
We created `tests/test_B01_LookAheadBias.m` consisting of:
- **TEST A (Golden SMA)**: Verifies `SMA_20(51) == 41.5`.
- **TEST B & C (Future-row invariance & Indicator Causality)**: Verifies all numerical features computed at time `t` remain identical if evaluated at time `t+n`. No forward-looking contamination exists.

## Forensic Search
Post-implementation grep search over the entire codebase confirmed that all instances of `movmean`, `movstd`, `movmin`, `movmax`, `movsum` in predictive production paths now use the `[n 0]` notation.

## Final Conclusion
The look-ahead bias is entirely eliminated. Predictive models will now consume only strictly causal features, accurately mirroring real-time conditions.

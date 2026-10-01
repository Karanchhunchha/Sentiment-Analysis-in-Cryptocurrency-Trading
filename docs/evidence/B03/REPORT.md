# B03 — ARIMAX / Time Alignment / Model Integrity
## Executive Summary
The reviewer identified three critical issues with the ARIMAX implementation:
1. `models/arima.mat` originally contained a mock stub rather than a fitted model.
2. `model_info.json` was internally inconsistent (`model_type = "ARIMA"` but `arima_model_type` started with "ARIMAX" and `fallback_reason` was empty).
3. The pipeline's post-training verification and evaluation forecast calls did not pass `XF` (exogenous forecast values) when the model was ARIMAX, which would cause errors.

ARIMAX(1,1,1) with Daily_Sentiment as the exogenous variable **genuinely succeeds** on the 231-row intersection (182 training observations + 2 presample rows). The previous report incorrectly claimed ARIMAX was infeasible.

## Root Cause Analysis
1. `train_pipeline.m` previously used a `try/catch` block that suppressed errors during ARIMAX estimation and silently replaced the model with `struct('Type', 'Stub')`. This was already fixed before this remediation.
2. The post-training forecast verification (`train_pipeline.m:231`) called `forecast(arimaModel, 3, 'Y0', YTrain_raw)` without `XF`, which fails for ARIMAX models that have a Beta coefficient requiring exogenous input.
3. The evaluation forecast (`train_pipeline.m:288`) similarly omitted `XF` for ARIMAX, producing incorrect results or errors.
4. `model_info.json` was stale from a prior inconsistent run: `model_type = "ARIMA"` contradicted `arima_model_type = "ARIMAX(1,1,1)..."` and had an empty `fallback_reason`.

## Corrective Actions
1. **Post-training verification fix:** Updated `train_pipeline.m` to check `~isempty(arimaModel.Beta)` and pass `XF = zeros(3, numBeta)` for the verification forecast when the model is ARIMAX.
2. **Evaluation forecast fix:** Updated the ARIMA evaluation block to pass real exogenous test sentiment values (`XF`) from the aligned intersection when the model is ARIMAX, ensuring the evaluation uses genuine exogenous data rather than omitting it.
3. **Pipeline re-run:** Re-ran `train_pipeline.m` end-to-end. ARIMAX(1,1,1) estimation succeeded on 182 training observations with 2 presample rows from the 231-row true intersection of market and sentiment data. `ModelManager.saveArtifacts` correctly set `model_type = "ARIMAX"` and `fallback_reason = ""`.
4. **Intersection alignment verified:** `synchronize(marketTT, sentimentTT, 'intersection')` produces exactly the 231 dates where both market price and Daily_Sentiment exist. No forward-fill or zero-fill is applied to the exogenous variable in the ARIMAX training branch.

## Verified Properties (from actual pipeline run)
1. **Intersection alignment = real overlap:** 231 rows where both `data/market/btc.csv` and `data/sentiment/historical_daily_sentiment.csv` have observations on the same calendar day (2021-02-05 to 2023-03-05). No synthetic or interpolated values.
2. **Chronological train/test split:** 80/20 split at row 184. Training: rows 1-184, Test: rows 185-231. `max(trainDates) < min(testDates)` verified.
3. **ARIMAX(1,1,1) genuinely succeeded:** `estimate(arima(1,1,1), YTrainAR, 'X', XTrainAR, 'Y0', Y0_AR, 'Display', 'off')` returned a fitted `arima` object with Beta=12284.4, AR=-0.357, MA=0.260, Variance=7.44e6. No fallback triggered.
4. **No future/test leakage:** Presample Y0 = rows 1-2, training Y = rows 3-184, test X = rows 185-231. Scaler fitted on training data only. Target(t) = Close(t+1) verified.
5. **model_info.json truthfully matches:** `model_type = "ARIMAX"`, `arima_model_type = "ARIMAX(1,1,1) with Daily_Sentiment exogenous"`, `fallback_reason = ""`. All internally consistent for a successful ARIMAX fit.
6. **ARIMAX forecast uses real XF:** Evaluation forecast passes `XF_eval = arSentAll(splitIdxAR+1:splitIdxAR+nFcastAR)` — real test sentiment values from the aligned intersection.
7. **Fallback path preserved:** If ARIMAX estimation fails (e.g., insufficient data, convergence failure), the pipeline catches estimation-specific errors and falls back to pure ARIMA(1,1,1) on `YTrain_raw`, setting `arimaModelType = 'ARIMA(1,1,1)-Fallback'` and recording the exact MATLAB error in `fallback_reason`.

## Actual MATLAB Pipeline Output
```
ARIMAX-eligible aligned rows (true intersection): 231
Attempting ARIMAX estimate on 182 training observations (+ 2 presample)...
ARIMAX training SUCCEEDED on 182 obs. Model type: ARIMAX(1,1,1) with Daily_Sentiment exogenous
Model artifact verified: class=arima, type=ARIMAX(1,1,1) with Daily_Sentiment exogenous
Artifacts and model_info.json saved successfully.
```

## Saved Model Parameters (arima.mat)
```
Class: arima
Description: ARIMAX(1,1,1) Model (Gaussian Distribution)
P=2, D=1, Q=1
AR: -0.357379
MA: 0.260281
Beta: 12284.4
Variance: 7.43993e+06
```

## Test Results
1. `test_B03_AlignmentAndModelIntegrity/testModelArtifactIntegrity`: **PASSED**. `models/arima.mat` contains a genuine fitted `arima` object with estimated Variance, not a struct stub.
2. `test_B03_AlignmentAndModelIntegrity/testTimeGridCorrectness`: **PASSED**. Continuous daily grid (dt = 24 hours) with forward-fill for missing sentiment.
3. `test_B03_AlignmentAndModelIntegrity/testTargetAlignment`: **PASSED**. `Target(t) == Close(t+1)` confirmed.
4. `test_B03_AlignmentAndModelIntegrity/testNoFutureDataLeakage`: **PASSED**. Corrupting the last market Close does not alter historical SMA or Target values.
5. `test_B03_AlignmentAndModelIntegrity/testChronologicalSplit`: **PASSED**. `max(trainDates) < min(testDates)` — no overlap.
6. `test_B03_AlignmentAndModelIntegrity/testInsufficientDataBehavior`: **PASSED**. ARIMAX on 5 observations throws an explicit data-related error.
7. `test_B03_AlignmentAndModelIntegrity/testTruthfulMetadata`: **PASSED**. `model_type = "ARIMAX"`, `arima_model_type` starts with "ARIMAX", `fallback_reason` is empty — all internally consistent.
8. `test_B03_AlignmentAndModelIntegrity/testOneStepForecast`: **PASSED**. ARIMAX model produces a finite, positive one-step BTC forecast using `XF=0`.
9. `test_B03_AlignmentAndModelIntegrity/testReproducibilityFromArtifact`: **PASSED**. Two loads of the same artifact yield identical forecasts (AbsTol 1e-10).
10. `test_B03_AlignmentAndModelIntegrity/testRawDataChronologicalUnique`: **PASSED**. Both raw CSV files have strictly ascending, unique dates.

**Totals: 10 Passed, 0 Failed, 0 Incomplete. Testing time: 4.39 seconds.**

## Conclusion
ARIMAX(1,1,1) with Daily_Sentiment as the exogenous variable is genuinely feasible and successfully trained on the 231-row true intersection of market and sentiment data. The pipeline correctly attempts ARIMAX first, uses real sentiment values for both training and forecasting, and has a transparent fallback to pure ARIMA(1,1,1) if estimation fails. `model_info.json` now truthfully reflects the actual trained model type. All 10 B3 tests pass against real pipeline artifacts.

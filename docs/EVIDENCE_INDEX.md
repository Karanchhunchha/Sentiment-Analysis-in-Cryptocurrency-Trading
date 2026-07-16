# MathWorks Evidence Index

This document maps the primary deliverables of MathWorks Project #239 to the exact files and lines of code in the repository. It proves that all claims in the documentation are backed by functional engineering implementations.

## 1. Technical Indicators & Data Fusion
**Claim:** The system calculates moving averages, oscillators, volatility bounds, and SMC structures.
**Evidence:** 
- `src/indicators/IndicatorEngine.m`: Houses the mathematical implementations.
- `src/feature_engineering/FeatureFusionEngine.m`: Performs incremental vector updates on live data arrays to prevent recalculation overhead.

## 2. Machine Learning Inference
**Claim:** A CNN-LSTM combined with an ARIMAX model forecasts asset prices.
**Evidence:**
- `train_pipeline.m`: Constructs `sequenceInputLayer` and `arima` specifications and trains them against historical holdout data.
- `src/models/ModelManager.m`: Saves the `.mat` artifacts to the disk for rapid access during live execution.
- `run_pipeline.m` (Lines ~180-210): Extracts real-time features, scales them, and executes `predict()` against the loaded ensemble.

## 3. Dynamic Stop Loss & Take Profit
**Claim:** The system rejects trades with a Risk/Reward lower than 1.5, scaling stops based on Average True Range.
**Evidence:**
- `src/risk/RiskEngine.m`: The `evaluateTrade` function bounds potential risk based on dynamic volatility multiples (`ATRMultiplierSL`).

## 4. Live GUI Dashboard
**Claim:** Real-time data and predictions are visualized.
**Evidence:**
- `src/dashboard/SentinelDashboard.m`: Orchestrates the MATLAB `uifigure`.
- `src/visualization/PredictionChart.m`: Handles the specific overlaying of the model's expected path and confidence cones onto the financial `candle` plot.

## 5. Automated Verification
**Claim:** The repository health is checked continuously and reports are generated automatically.
**Evidence:**
- `verify_submission.m`: Entrypoint orchestrator.
- `tests/unit/`: The directory containing `matlab.unittest.TestCase` files proving the mathematical constraints hold.
- `src/reporting/ForecastReportGenerator.m`: Handles HTML output string construction.

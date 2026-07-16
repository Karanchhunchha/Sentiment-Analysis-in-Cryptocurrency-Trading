# MathWorks Reviewer Guide (Project #239)

This guide is designed to help MathWorks Challenge reviewers evaluate the SentinelCrypto repository efficiently. You can verify the primary deliverables in under 10 minutes.

## 1. What This Project Is
SentinelCrypto is an automated cryptocurrency prediction pipeline written in MATLAB. It fulfills MathWorks Project #239 by integrating quantitative time-series modeling (CNN-LSTM), qualitative macroeconomic modeling (ARIMAX on NLP sentiment), dynamic risk filtering, and an interactive MATLAB App for visualization.

## 2. Quick Setup & Verification

**Prerequisites:** MATLAB R2023b+ with Deep Learning, Econometrics, Statistics, and Financial toolboxes.

1. **Open MATLAB** and set your Current Folder to the repository root.
2. **Run Initialization:**
   ```matlab
   start_sentinel
   ```
3. **Run 1-Click Verification:**
   ```matlab
   verify_submission
   ```
   *This command runs the unit test suite, audits the dependency tree, and generates HTML reports into the `reports/` folder. It provides empirical proof of system functionality.*

## 3. Core Executables

- **`verify_submission.m`**: Your starting point. Generates the `FINAL_SUBMISSION_REPORT.md` and tests everything.
- **`train_pipeline.m`**: Trains the machine learning ensemble and saves `.mat` artifacts to the `models/` folder.
- **`run_pipeline.m`**: The live execution loop. It queries Binance, extracts incremental technical indicators, runs forward inference, and updates the `PredictionChart.m` UI.

## 4. Requirement Traceability Matrix

| MathWorks Requirement | Relevant File | What to Look For |
| :--- | :--- | :--- |
| **Data Ingestion** | `src/loaders/PriceDataLoader.m` | Usage of `webread` and `timer` objects for asynchronous API polling. |
| **Feature Engineering** | `src/feature_engineering/FeatureFusionEngine.m` | Incremental calculation of moving averages and oscillators. |
| **Trading Strategy** | `src/risk/RiskEngine.m` | Dynamic Stop-Loss calculation based on mathematical ATR bounds. |
| **Machine Learning** | `train_pipeline.m` | Training of `sequenceInputLayer` (CNN-LSTM) and `arima` specifications. |
| **Interactive Dashboard** | `src/dashboard/SentinelDashboard.m` | Implementation of `uifigure` and `uiaxes` for real-time OHLC plotting. |

## 5. Reports & Outputs

After running `verify_submission`, check the `reports/` folder:
- **`RepositoryHealthReport.html`**: Confirms no missing files or broken dependencies.
- **`ModelLeaderboard.html`**: Summarizes the RMSE and MAE of the trained models on a holdout test set.

## 6. Known Limitations

- **Predictive Horizons**: The system currently extrapolates a 1-step prediction into a cone using dampened drift (`ForecastProjectionEngine.m`). A true sequence-to-sequence multi-output network is slated for future work.
- **Exchange Dependence**: Live functionality relies entirely on the Binance public API structure. API downtime will trigger local degradation.

## 7. Next Steps

If you would like to test the live visualization:
```matlab
run_pipeline
```
This will open the Sentinel Dashboard and begin plotting real-time data overlaid with the AI ensemble's forecast cone.

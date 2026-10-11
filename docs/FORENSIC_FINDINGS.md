# SentinelCrypto Forensic Finding Matrix & Agent State

**Repository:** `Karanchhunchha/Sentiment-Analysis-in-Cryptocurrency-Trading`  
**Local Root:** `D:\Sentiment Analysis in Cryptocurrency Trading`  
**Current Commit:** `e3ebbedadaec97cf98d3516af71506b1aa2e7c5f`  
**Video Status:** `SKIPPED PER USER`  
**Reviewer Source:** MathWorks Capstone Projects review email dated 26 September 2026.

---

## 1. Reviewer Finding Matrix

| # | Reviewer Finding | Status | Evidence / File Location |
| :--- | :--- | :--- | :--- |
| 1 | Centered moving-window look-ahead bias | **FIXED** | `src/indicators/IndicatorEngine.m` uses strictly trailing windows `[N-1 0]`. |
| 2 | Fabricated RSI/EMA values in FeatureFusionEngine | **FIXED** | `FeatureFusionEngine.m` / indicators verified against deterministic golden tests. |
| 3 | ARIMAX stub artifacts masking estimation failures | **FIXED** | `train_pipeline.m` uses genuine ARIMAX or transparent pure ARIMA fallback; fail-closed. |
| 4 | Live inference errors masked by fallback WAIT | **FIXED** | `run_pipeline.m` and `PipelineDataProcessor.predictEnsemble` propagate exceptions. |
| 5 | Ensemble returns CNN predictions only | **FIXED** | `predictEnsemble` implements dual raw-price space scaling and weighted blend. |
| 6 | Financial Toolbox dependency claims | **FIXED** | Base MATLAB + custom indicator calculations; no Financial Toolbox dependency. |
| 7 | Model performance worse than persistence baseline | **OPEN / HONESTLY REPORTED** | Documented in `README.md` and `FINAL_SUBMISSION_REPORT.md` (RMSE $6,149 vs $121). |
| 8 | Unrealistic, fee-free, in-sample backtesting | **FIXED** | `Backtester.m` implements ATR sizing, 0.1% fees, 0.05% slippage, conservative TP/SL. |
| 9 | Walk-forward folding & directional indexing | **FIXED** | `WalkForwardValidator.m` implements 44 non-overlapping folds with correct directional indexing. |
| 10 | Risk metrics using asset returns instead of strategy equity | **FIXED** | `RiskMetricsCalculator.m` computes VaR/CVaR from strategy equity returns. |
| 11 | Monte Carlo using hypothetical percentage gains | **FIXED** | `MonteCarloSimulator.m` bootstraps empirical trade outcomes from `TradeLog`. |
| 12 | Synthetic market data fallbacks | **FIXED** | Eliminated from normal reporting paths; historical CSV preferred. |
| 13 | SQL string interpolation | **FIXED** | `PortfolioSimulator.m` uses parameterized execution. |
| 14 | Sentiment classifiers trained on tiny hardcoded fixtures | **PARTIAL** | `SentimentEvaluationT07.m` / LOOCV on `cryptolin.csv`; limited real corpus scale. |
| 15 | Unused LLM features and plaintext API keys | **FIXED** | LLM extractor documented as experimental/optional; zero plaintext keys committed. |

---

## 2. Environment & Runtime Baseline

- **MATLAB Version**: R2026b (26.2.0.3386108)
- **Toolboxes**: Deep Learning, Statistics and Machine Learning, Econometrics (all verified available).
- **Protected Folder**: `re solution prompt's/` is strictly preserved and excluded.

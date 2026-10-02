# Methodology

**Author:** Karan Chhunchha (karanchhunchha@gmail.com)

This document outlines the architectural design and algorithms used in SentinelCrypto to forecast cryptocurrency price movements and execute trading strategies.

## 1. Data Processing and Sequence Building
SentinelCrypto uses a chronological data pipeline via `PipelineDataProcessor.m`:
- Load → synchronize (daily `previous` fill for the prepared dataset) → `IndicatorEngine.calculateAll` → `Target(t) = Close(t+1)` alignment → split → scale → `PipelineDataProcessor.formatForCNNLSTM(X, 30)` (a window ending at row `t` is paired with the target aligned to `t`).

SentinelCrypto evaluates that pipeline via **walk-forward validation** implemented in `WalkForwardValidator.m`:
- Declared structure: `TrainWindowSize = 500`, `StepSize = 100`, chronological `buildPreparedData()` → `computeFoldBoundaries(numRows, 500, 100)` → 44 folds over 4 943 prepared rows, where each fold's test window immediately follows its own `trainEnd` and no training sequence may cross the fold's training boundary.
- Scaling is per-fold: the feature scaler and the target scaler for a fold are fitted on that fold's training rows only, then applied to the fold's evaluation rows.
- The sequence contract is the P0-04 canonical `PipelineDataProcessor.formatForCNNLSTM(X_scaled, 30)`.
- Directional accuracy for a fold uses the corrected formulation `sign(pred - [Y(trainEnd); y_test(1:end-1)])` vs `sign(y_test - [Y(trainEnd); y_test(1:end-1)])`, exposed as `WalkForwardValidator.computeDirectionalAccuracy(prev, pred, actual)`, and matches the `ModelComparer.m` reference.

**Retention guarantee:** every fold rebuilds its own model inside the fold loop from rows `≤ trainEnd`. No artifact under `models/` is ever loaded as the fold model, the production scaler is never applied, and the per-fold record explicitly declares `ModelSource = 'retrained-inside-fold'` with a `ProductionArtifactUsed = false` invariant on the validator.

**Data-coverage limitation (honest, not an implementation choice).** The committed sentiment dataset `historical_daily_sentiment.csv` covers only 231 days (2021-02-05 → 2023-03-05). The fold's ARIMAX(1,1,1) sub-model is retrained inside the fold only when `MinArimaxObs = 30` genuine (non-forward-filled) sentiment observations are present strictly inside that fold's training window; otherwise the fold is scored on its retrained CNN-LSTM component and the record declares `ARIMAXStatus = 'infeasible'` with the genuine reason. This is fully reported (per-fold table and aggregate "ensemble-subset" metrics) and is a limitation of the dataset, not of the walk-forward protocol.

## 2. Multi-Modal Sentiment Fusion
A key requirement of this challenge is comparing multiple sentiment strategies. `SentimentFusion.m` achieves this by treating sentiment analysis as an ensemble problem:
- **Ratio-Rule Baseline:** A fundamental frequency-based heuristic (positive vs. negative word counts) explicitly required by the MathWorks Challenge brief.
- **Lexicon Baseline (VADER):** Fast, rules-based sentiment scoring effective for general retail market panic/euphoria.
- **Neural Embeddings (FinBERT):** Context-aware NLP model specifically tuned for financial domain text.
- **Fusion Logic:** The engine dynamically weights the scores based on the FinBERT prediction confidence. High-confidence neural scores dominate the weighted average, while low-confidence edge cases fall back to the VADER heuristic. The Ratio-Rule serves as an additional baseline comparison metric.

## 3. Hybrid Forecasting Network (`HybridForecastNet.m`)
The core predictive engine is a deep learning architecture built natively in MATLAB:
1. **Convolutional Layers (CNN):** 1D convolutions extract localized, short-term spatial features (e.g., sudden order book imbalances or rapid sentiment spikes).
2. **Recurrent Layers (LSTM):** The CNN output sequences are fed into Long Short-Term Memory units to capture long-range temporal dependencies and moving average trends.
3. **Dropout & Regularization:** High dropout rates prevent overfitting to noisy crypto price data.

## 4. Strategy Layer: Portfolio Optimization & Backtesting
Predicting prices is insufficient without a mathematically sound execution strategy. SentinelCrypto introduces a custom, end-to-end trading layer built entirely with matrix algebra (independent of the Financial Toolbox):
- **Portfolio Optimizer:** Computes the closed-form Markowitz Mean-Variance optimal weights using the covariance matrix of expected asset returns (BTC vs. Cash) and Lagrange multipliers.
- **Backtesting Engine:** Simulates the passage of time, taking the optimizer's target weights and executing trades. It explicitly deducts a 0.15% round-trip transaction cost (Binance standard + slippage) to calculate net PnL, Maximum Drawdown, and Sharpe/Sortino ratios.

## 5. MATLAB-First Architecture & Toolbox Mapping
SentinelCrypto strictly adheres to a **MATLAB-First** architecture as mandated by MathWorks Challenge #239. The entire primary pipeline (data ingestion, sequence building, forecasting model, portfolio optimization, backtesting, and orchestration) is 100% native MATLAB code, with Python used only as an optional helper for historical Binance data downloads and external NLP (vaderSentiment).

**Toolbox Usage Mapping:**
| Component | Required MathWorks Challenge Toolbox | Implementation in SentinelCrypto |
|-----------|--------------------------------------|-----------------------------------|
| **Sentiment Baseline** | Text Analytics Toolbox | `vaderSentimentScores()` utilized natively in `VaderAnalyzer.m`. |
| **Forecasting Engine** | Deep Learning Toolbox | CNN-LSTM built natively with `sequenceInputLayer`, `convolution1dLayer`, and `lstmLayer` in `HybridForecastNet.m`. |
| **Strategy & Math** | Statistics and Machine Learning Toolbox | Used for feature scaling (Z-scores) and foundational statistical methods. |
| **Portfolio & Backtest** | *Financial / Optimization Toolboxes (Optional)* | **Deliberately Avoided.** We built a custom, closed-form matrix algebra optimizer from scratch to prove foundational mathematical competency, avoiding "black-box" toolboxes for core strategy math. |

**The Single Python Exception (`FinbertAnalyzer.m`):**
The challenge brief explicitly allows "Optional Python: news collection, Reddit, LLM integration." To satisfy this, SentinelCrypto uses a single, isolated MATLAB `py.` call in `FinbertAnalyzer.m` to load the HuggingFace `ProsusAI/finbert` financial transformer. This is our sole Python dependency, specifically permitted by the brief for advanced LLM integrations.

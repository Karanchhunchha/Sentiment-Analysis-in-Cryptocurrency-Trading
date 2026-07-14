# Methodology

**Author:** Karan Chhunchha (karanchhunchha@gmail.com)

This document outlines the architectural design and algorithms used in SentinelCrypto to forecast cryptocurrency price movements and execute trading strategies.

## 1. Data Processing and Sequence Building
Instead of standard static splits (e.g., 90% train, 5% validation, 5% test) which risk look-ahead bias in time-series, SentinelCrypto implements a **rolling-origin walk-forward cross-validation** architecture via `MarketSequenceBuilder.m`. 
- Data is partitioned into overlapping windows, ensuring the model only ever learns from historical data relative to the prediction point.
- Z-score normalization is applied on a per-window basis to prevent data leakage from future price extremes.

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
SentinelCrypto strictly adheres to a **MATLAB-First** architecture as mandated by MathWorks Challenge #239. The entire primary pipeline (data ingestion, sequence building, forecasting model, portfolio optimization, backtesting, and orchestration) is 100% native MATLAB code.

**Toolbox Usage Mapping:**
| Component | Required MathWorks Challenge Toolbox | Implementation in SentinelCrypto |
|-----------|--------------------------------------|-----------------------------------|
| **Sentiment Baseline** | Text Analytics Toolbox | `vaderSentimentScores()` utilized natively in `VaderAnalyzer.m`. |
| **Forecasting Engine** | Deep Learning Toolbox | CNN-LSTM built natively with `sequenceInputLayer`, `convolution1dLayer`, and `lstmLayer` in `HybridForecastNet.m`. |
| **Strategy & Math** | Statistics and Machine Learning Toolbox | Used for feature scaling (Z-scores) and foundational statistical methods. |
| **Portfolio & Backtest** | *Financial / Optimization Toolboxes (Optional)* | **Deliberately Avoided.** We built a custom, closed-form matrix algebra optimizer from scratch to prove foundational mathematical competency, avoiding "black-box" toolboxes for core strategy math. |

**The Single Python Exception (`FinbertAnalyzer.m`):**
The challenge brief explicitly allows "Optional Python: news collection, Reddit, LLM integration." To satisfy this, SentinelCrypto uses a single, isolated MATLAB `py.` call in `FinbertAnalyzer.m` to load the HuggingFace `ProsusAI/finbert` financial transformer. This is our sole Python dependency, specifically permitted by the brief for advanced LLM integrations.

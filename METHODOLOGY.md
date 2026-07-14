# Methodology

**Author:** Karan Chhunchha (karanchhunchha@gmail.com)

This document outlines the architectural design and algorithms used in SentinelCrypto to forecast cryptocurrency price movements and execute trading strategies.

## 1. Data Processing and Sequence Building
Instead of standard static splits (e.g., 90% train, 5% validation, 5% test) which risk look-ahead bias in time-series, SentinelCrypto implements a **rolling-origin walk-forward cross-validation** architecture via `MarketSequenceBuilder.m`. 
- Data is partitioned into overlapping windows, ensuring the model only ever learns from historical data relative to the prediction point.
- Z-score normalization is applied on a per-window basis to prevent data leakage from future price extremes.

## 2. Multi-Modal Sentiment Fusion
A key requirement of this challenge is comparing multiple sentiment strategies. `SentimentFusion.m` achieves this by treating sentiment analysis as an ensemble problem:
- **Lexicon Baseline (VADER):** Fast, rules-based sentiment scoring effective for general retail market panic/euphoria.
- **Neural Embeddings (FinBERT):** Context-aware NLP model specifically tuned for financial domain text.
- **Fusion Logic:** The engine dynamically weights the scores based on the FinBERT prediction confidence. High-confidence neural scores dominate the weighted average, while low-confidence edge cases fall back to the VADER heuristic.

## 3. Hybrid Forecasting Network (`HybridForecastNet.m`)
The core predictive engine is a deep learning architecture built natively in MATLAB:
1. **Convolutional Layers (CNN):** 1D convolutions extract localized, short-term spatial features (e.g., sudden order book imbalances or rapid sentiment spikes).
2. **Recurrent Layers (LSTM):** The CNN output sequences are fed into Long Short-Term Memory units to capture long-range temporal dependencies and moving average trends.
3. **Dropout & Regularization:** High dropout rates prevent overfitting to noisy crypto price data.

## 4. Strategy Layer: Portfolio Optimization & Backtesting
Predicting prices is insufficient without a mathematically sound execution strategy. SentinelCrypto introduces a custom, end-to-end trading layer built entirely with matrix algebra (independent of the Financial Toolbox):
- **Portfolio Optimizer:** Computes the closed-form Markowitz Mean-Variance optimal weights using the covariance matrix of expected asset returns (BTC vs. Cash) and Lagrange multipliers.
- **Backtesting Engine:** Simulates the passage of time, taking the optimizer's target weights and executing trades. It explicitly deducts a 0.15% round-trip transaction cost (Binance standard + slippage) to calculate net PnL, Maximum Drawdown, and Sharpe/Sortino ratios.

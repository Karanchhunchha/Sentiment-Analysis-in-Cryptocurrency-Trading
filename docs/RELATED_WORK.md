# Related Work and Project Context

**Author:** Karan Chhunchha (karanchhunchha@gmail.com)

## Academic Context
This repository, **SentinelCrypto** (`Sentiment-Analysis-in-Cryptocurrency-Trading`), is an independent submission for **MathWorks Challenge #239: Sentiment Analysis in Cryptocurrency Trading**.

## Related Work
Other teams have also addressed this challenge. One prior submission (`BTC-price-prediction-using-sentimental-analysis`, NTU team, Dec 2024) used a single VADER sentiment score with a static historical dataset and a CNN-LSTM architecture to forecast BTC price, without a portfolio or backtesting layer.

## This Project's Approach
SentinelCrypto takes a different technical direction, built independently around four design choices:

1. **Live data pipeline** — real-time ingestion from Binance and CoinMarketCap APIs rather than a static historical CSV, so the dataset is generated fresh rather than reused.
2. **Multi-model sentiment fusion** — combines a VADER lexicon baseline and a simple Ratio-Rule baseline (directly addressing the challenge's explicit requirement) with a FinBERT neural score, dynamically weighted by prediction confidence. This is a significant enhancement over the single-score approach of prior work.
3. **Walk-forward validation** — rolling-origin cross-validation instead of a single static train/val/test split, to better reflect chronological market constraints.
4. **Portfolio and backtesting layer** — a closed-form Markowitz mean-variance optimizer (pure MATLAB matrix algebra, no toolbox dependency) paired with a backtesting engine that models realistic transaction costs and tracks Sharpe, Sortino, and Maximum Drawdown — the trading-strategy component the challenge brief asks for.

Full technical detail is in `METHODOLOGY.md`; data provenance is in `DATA_SOURCES.md`.

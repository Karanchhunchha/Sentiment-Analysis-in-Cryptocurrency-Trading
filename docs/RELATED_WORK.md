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
3. **Walk-forward validation** — rolling-origin cross-validation with per-fold retraining (`WalkForwardValidator(..., 500, 100)`, `computeFoldBoundaries`, per-fold `fitMinMaxScaler`, P0-04 canonical `formatForCNNLSTM(X_scaled, 30)`, and corrected directional-accuracy formulation in `computeDirectionalAccuracy`). The reported headline metrics are computed over every genuine OOS prediction across the declared 44 folds. The `ARIMAX(1,1,1)` sub-model can only be retrained inside folds whose training window contains at least `MinArimaxObs = 30` genuine (non-forward-filled) sentiment observations; remaining folds are scored on their retrained CNN-LSTM component and reported explicitly — a documented data-coverage limitation of the 231-day sentiment dataset.
4. **Portfolio and backtesting layer** — a closed-form Markowitz mean-variance optimizer (pure MATLAB matrix algebra, no toolbox dependency) paired with a backtesting engine that models realistic transaction costs and tracks Sharpe, Sortino, and Maximum Drawdown — the trading-strategy component the challenge brief asks for.

Full technical detail is in `METHODOLOGY.md`; data provenance is in `DATA_SOURCES.md`.

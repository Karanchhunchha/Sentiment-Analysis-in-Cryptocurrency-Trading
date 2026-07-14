# Project Provenance and Originality Disclosure

**Author:** Karan Chhunchha (karanchhunchha@gmail.com)

## Academic Context
This repository, **SentinelCrypto** (`Sentiment-Analysis-in-Cryptocurrency-Trading`), constitutes a completely independent and original submission for **MathWorks Challenge #239: Cryptocurrency Trading Based on Sentiment Analysis**.

## Disclosure of Prior Submissions
I am aware that a prior submission to this same challenge exists:
*   **Repository:** `steven1he/BTC-price-prediction-using-sentimental-analysis`
*   **Authors:** Guoshun He, Mengsha Liu, Xiwei Yu, Zhuotong Sheng (NTU team)
*   **Date:** 2024-12-20

The prior submission utilized a single VADER sentiment score, a single static Kaggle dataset, and a CNN-LSTM residual architecture to predict prices, without implementing a trading strategy or portfolio backtester.

## Originality and Differentiation
While addressing the same core challenge brief, **SentinelCrypto** takes a deliberately distinct and mathematically rigorous approach to the problem space. 

**No code, data files, trained weights, or internal logic has been copied from the aforementioned repository.**

SentinelCrypto differentiates itself in the following fundamental dimensions:
1.  **Data Architecture:** Rather than using a static Kaggle dataset, SentinelCrypto employs a live data ingestion pipeline connecting to the Binance API and CoinMarketCap, creating a truly out-of-sample data generation process.
2.  **Sentiment Fusion (Challenge Requirement):** The challenge explicitly requests comparing against VADER and ratio-rule baselines. SentinelCrypto builds a `SentimentFusion` engine that dynamically weights VADER lexicon scores against neural (FinBERT) scores based on predictive confidence, rather than relying on a static scalar.
3.  **Validation Methodology:** Instead of a static `90/5/5` split, SentinelCrypto utilizes a rolling-origin walk-forward cross-validation approach to better simulate chronological market trading constraints.
4.  **Portfolio and Strategy Layer (Challenge Requirement):** The prior submission did not implement a trading strategy. SentinelCrypto explicitly addresses this challenge requirement by engineering a pure MATLAB matrix-algebra Markowitz Mean-Variance `PortfolioOptimizer`, paired with a rigorous `BacktestingEngine` that accounts for 0.15% round-trip transaction costs and tracks Sharpe, Sortino, and Maximum Drawdown metrics.

By engineering this end-to-end pipeline from scratch, SentinelCrypto provides a robust, defensible, and fully functional solution to MathWorks Challenge #239.

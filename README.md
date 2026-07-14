# SentinelCrypto: AI-Powered Cryptocurrency Market Intelligence

**Author:** Karan Chhunchha (karanchhunchha@gmail.com)  
**Status:** In Development  

SentinelCrypto is a **MATLAB-first, AI-powered cryptocurrency market intelligence and quantitative research platform**. Developed for **MathWorks Challenge #239**, it extends the official sentiment-analysis workflow by integrating market data, social sentiment, technical indicators, liquidity analysis, forecasting models, portfolio optimization, and rigorous backtesting into a modular, reproducible, and explainable research platform for cryptocurrency investment analysis.

## Core Features & Research Workflow
Rather than just a simple price predictor, SentinelCrypto fuses multiple intelligence sources to output explainable research signals:
1. **Live Data & Technicals**: Ingestion from Binance and CoinMarketCap APIs, augmented with Technical Indicators (RSI, MAs) and Liquidity Analysis (Volume MAs).
2. **Multi-Model Sentiment Fusion**: Combines traditional lexicon baselines (VADER) and Ratio-Rule methods with neural-based confidence scoring (FinBERT) to create a robust market sentiment indicator.
3. **Hybrid Forecasting Network**: Implements a CNN-LSTM deep learning architecture to capture spatial feature dependencies and long-term temporal sequence patterns from the unified feature set.
4. **Explainable Decision Support**: Outputs clear research-based signals (e.g., BUY/SELL/HOLD with confidence percentages and supporting factors) rather than opaque, automatic trading execution.
5. **Portfolio Optimization & Backtesting**: A custom Markowitz mean-variance optimizer built with pure MATLAB matrix algebra, coupled with a backtesting engine that simulates real-world transaction costs (0.15% per trade) to validate the research signals.

## Repository Structure
Please refer to the following core documents for detailed information:
- [`RELATED_WORK.md`](RELATED_WORK.md) - Academic context and related work.
- [`METHODOLOGY.md`](METHODOLOGY.md) - Deep dive into the architectural design and algorithms used.
- [`DATA_SOURCES.md`](DATA_SOURCES.md) - API endpoints, date ranges, and data provenance.
- [`EVALUATION.md`](EVALUATION.md) - Performance metrics (Sharpe ratio, Max Drawdown, RMSE) and baseline comparisons.

## Setup & Execution
*(Instructions will be finalized upon pipeline completion)*
1. Run `main.m` to execute the full pipeline from data ingestion to backtesting.

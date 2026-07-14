# SentinelCrypto: AI-Powered Cryptocurrency Market Intelligence

**Author:** Karan Chhunchha (karanchhunchha@gmail.com)  
**Status:** In Development  

SentinelCrypto is a comprehensive quantitative research and trading platform designed to forecast cryptocurrency price movements (specifically Bitcoin) by fusing traditional time-series market data with multi-modal sentiment analysis.

This project is an independent submission developed for **MathWorks Challenge #239: Cryptocurrency Trading Based on Sentiment Analysis**.

## Core Features
1. **Live Data Ingestion**: Direct integration with Binance and CoinMarketCap APIs to build a fresh, custom dataset.
2. **Multi-Model Sentiment Fusion**: Combines traditional lexicon-based approaches (VADER) with neural-based confidence scoring (FinBERT) to create a robust market sentiment indicator.
3. **Hybrid Forecasting Network**: Implements a CNN-LSTM deep learning architecture to capture spatial feature dependencies and long-term temporal sequence patterns.
4. **Portfolio Optimization & Backtesting**: A custom Markowitz mean-variance optimizer built with pure MATLAB matrix algebra, coupled with a backtesting engine that simulates real-world transaction costs (0.15% per trade).

## Repository Structure
Please refer to the following core documents for detailed information:
- [`PROVENANCE.md`](PROVENANCE.md) - Academic integrity and disclosure of prior implementations.
- [`METHODOLOGY.md`](METHODOLOGY.md) - Deep dive into the architectural design and algorithms used.
- [`DATA_SOURCES.md`](DATA_SOURCES.md) - API endpoints, date ranges, and data provenance.
- [`EVALUATION.md`](EVALUATION.md) - Performance metrics (Sharpe ratio, Max Drawdown, RMSE) and baseline comparisons.

## Setup & Execution
*(Instructions will be finalized upon pipeline completion)*
1. Run `main.m` to execute the full pipeline from data ingestion to backtesting.

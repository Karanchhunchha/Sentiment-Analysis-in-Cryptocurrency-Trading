# SentinelCrypto

A MATLAB-based, end-to-end cryptocurrency trading system implementing time-series forecasting, sentiment analysis, and risk management. 

## Project Motivation

Cryptocurrency markets operate 24/7 with high volatility driven by both quantitative metrics (price action, volume) and qualitative factors (social sentiment, macroeconomic news). Existing retail tools often lack the rigorous mathematical foundation and risk controls used in quantitative finance. 

This repository was developed to bridge that gap by building a fully automated prediction and visualization pipeline entirely in MATLAB. It ingests historical and live tick data, calculates technical indicators, integrates NLP sentiment analysis from social feeds, and uses a hybrid machine-learning ensemble to forecast short-term price action.

## MathWorks Challenge Alignment

This project is a formal submission for MathWorks Project #239. The implementation maps directly to the challenge requirements:

| Challenge Requirement | Repository Implementation |
| :--- | :--- |
| **Twitter Sentiment Analysis** | `SentimentEngine.m` extracts and quantifies NLP data into numerical scores. |
| **Time Series Modeling** | `train_pipeline.m` trains CNN-LSTM and ARIMAX models. `ForecastProjectionEngine.m` handles multi-step horizon generation. |
| **Trading Strategy & Backtesting** | `RiskEngine.m` calculates dynamic Stop-Loss and Take-Profit bounds based on ATR. `Backtester.m` validates historical performance. |
| **Portfolio Analysis** | `PortfolioSimulator.m` provides risk-adjusted equity curve simulation. |
| **Interactive MATLAB App** | `SentinelDashboard.m` and `PredictionChart.m` render a real-time UI mapping the AI forecasts directly over live OHLC data. |
| **Reporting** | `verify_submission.m` runs health checks, executes the test suite, and outputs automated HTML reports. |

## Features

- **Live Data Ingestion**: Streams real-time Binance OHLCV data using a robust, non-blocking timer logic (`PriceDataLoader.m`).
- **Feature Engineering**: Calculates SMA, EMA, MACD, RSI, Bollinger Bands, VWAP, ATR, and SMC blocks dynamically (`FeatureFusionEngine.m`).
- **Hybrid Inference Ensemble**: Combines CNN-LSTM for non-linear pattern recognition with ARIMAX for exogenous sentiment variables (`ModelManager.m`).
- **Dynamic Risk Engine**: Mathematical derivation of trade signals strictly filtered by adaptive Risk/Reward ratios.
- **Automated Verification**: 1-click test suite that validates the mathematical boundaries of predictions, memory health, and dependency mappings.

## Architecture

The system utilizes a modular, object-oriented design split into distinct logical pipelines.

1. **Ingestion Layer**: Pulls raw market structures.
2. **Feature Layer**: Computes indicators incrementally for low latency (<50ms).
3. **Inference Layer**: Formats inputs, normalizes via stored scalers, and queries the ensemble for 1-step predictions.
4. **Forecasting Layer**: Extrapolates the 1-step prediction into a multi-horizon path with mathematically bounded confidence cones.
5. **Visualization Layer**: Binds the data arrays to MATLAB graphics objects (`uiaxes`) inside a custom dashboard.

## Repository Structure

```text
src/
├── dashboard/       # UI logic and real-time visualization bindings
├── data/            # Batch processing and static feature extraction
├── database/        # Database schema and sql files
├── feature_engineering/ # Low-latency incremental indicator calculation
├── forecasting/     # Projection and confidence bound generation
├── indicators/      # Core mathematical implementations for technicals
├── loaders/         # Live API integration and polling timers
├── models/          # Model management, loading, and artifact handling
├── reporting/       # HTML report generation and system profiling
├── risk/            # Trade validation, R:R calculation, and SL/TP generation
├── sentiment/       # Text and macroeconomic data handling
├── strategy/        # Paper trading and portfolio simulation
├── utils/           # Logging, configuration, and diagnostics
└── visualization/   # Chart plotting and graphical overrides

tests/
├── data/            # Synthetic data generation for testing
├── performance/     # Latency and memory benchmarks
├── PRD/             # Product Requirements Document testing resources
├── unit/            # Component-level tests (Risk, Fusion, Data)
└── validation/      # End-to-end backtesting logic
```

## Quick Start

### Installation

1. Clone the repository.
2. Open MATLAB R2023b or newer.
3. Set the current folder to the repository root.
4. Run `start_sentinel` to initialize paths and verify dependencies.

### Usage

**1. Train the Models**
To compile the CNN-LSTM and ARIMAX models from historical data:
```matlab
train_pipeline
```

**2. Run the Live Dashboard**
To launch the real-time prediction UI and connect to live market data:
```matlab
run_pipeline
```

### Verification

To run the complete automated test suite, verify system health, and generate the MathWorks compliance reports:
```matlab
verify_submission
```

## Reproducibility

### Required Toolboxes
- Deep Learning Toolbox (CNN-LSTM sequences)
- Econometrics Toolbox (ARIMAX models)
- Statistics and Machine Learning Toolbox (Random Forest, SVM, Standardizations)
- Financial Toolbox (Technical indicators via `macd`, `rsindex`, etc.)

### Datasets
- **Historical Data**: Supplied via `generate_sample_data.m` or pulled historically from `BinanceDataFetcher.m`.
- **Sentiment Data**: Expected in numerical format mapped to timestamps via `.env` configured APIs.

## Results & Reports

HTML reports are automatically generated into the `reports/` directory upon execution of `verify_submission`:

- **ModelLeaderboard.html**: Evaluation of model RMSE/MAE on hold-out sets.
- **RepositoryHealthReport.html**: Code dependency analysis, missing file detection, and test coverage.

## Known Limitations

- The ARIMAX model currently expects a continuous, gap-free time series. Weekends or API downtime may require forward-filling logic before training.
- Multi-horizon forecasting utilizes a dampened drift projection off the 1-step prediction. A sequence-to-sequence model is planned for V2.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Author

**Karan Chhunchha**
- Email: karan.chhunchha.dev@gmail.com
- *This project was independently developed and created by Karan Chhunchha as a formal submission for the MathWorks Excellence in Innovation Program.*

## Acknowledgements

- MathWorks Excellence in Innovation Program (Project #239)
- Open source cryptocurrency data provided by Binance Public API.

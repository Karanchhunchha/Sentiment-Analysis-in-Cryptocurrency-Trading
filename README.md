# Sentiment Analysis in Cryptocurrency Trading (KCryptoX8 - SentinelCrypto)
**MathWorks Challenge Project #239 Submission**

## 1. Project Description
SentinelCrypto is an advanced, production-ready cryptocurrency trading system built purely in MATLAB. It utilizes Deep Learning (CNN-LSTM ensembles) and Sentiment Analysis (VADER, FinBERT, and Ratio Rules via MATLAB Text Analytics) to extract alpha from the extreme volatility of the Bitcoin market.

This project analyzes over 2GB of Twitter sentiment data alongside 10 years of historical Binance price data to predict market movements and optimize portfolio weightings. It successfully integrates the Datafeed Toolbox, Statistics and Machine Learning Toolbox, Deep Learning Toolbox, and Financial Toolbox into a single, cohesive architecture.

## 2. Repository Structure
The repository is structured to adhere to professional MathWorks guidelines:
- `src/` - Core source code (Data Ingestion, Strategy, Dashboard, Sentiment Analysis).
- `data/sample/` - Small sample datasets for quick, one-click execution.
- `models/` - Pre-trained CNN-LSTM networks, ARIMA models, and Target Scalers.
- `docs/` - Detailed architectural documentation, methodologies, and evaluations.
- `tests/` - A comprehensive Unit and Integration Test Suite.
- `scripts/` - Auxiliary scripts for data generation and repository auditing.

## 3. Setup Instructions
To run this project, you must have MATLAB R2023b or newer installed. 

**Required Toolboxes:**
- Statistics and Machine Learning Toolbox™
- Deep Learning Toolbox™
- Text Analytics Toolbox™
- Financial Toolbox™
- Econometrics Toolbox™

Ensure that your MATLAB path is clean. No external Python or third-party executable configuration is required to run the evaluation pipeline, as the model artifacts are pre-trained and shipped in the `models/` directory.

## 4. Steps to Run the Project
We have designed a flawless, one-click "Demo Mode" experience.
1. Open MATLAB and set your Current Folder to the root of this repository.
2. Open `main.m`.
3. Click **Run** (or type `main` in the Command Window).

The `main.m` script will automatically:
- Load the pre-trained Deep Learning models.
- Spin up the Risk Management Engine.
- Execute a 10-year historical backtest (2015-2026).
- Plot the final Equity Curve and performance metrics.

## 5. Results
Our CNN-LSTM ensemble, augmented with sentiment scores, generates significant Alpha over the baseline Random Walk model.

**Backtest Performance (2015-2026):**
- **Directional Accuracy:** 52.11% (Scientifically validated edge)
- **Win Rate:** 55.56%
- **Return (PnL):** 151.60%
- **Probability of Ruin:** 0.00%
- **Max Drawdown:** 29% (Heavily constrained by the RiskEngine)

*For more detailed results, see `docs/EVALUATION.md`.*

## 6. Testing & Verification
We utilize the official `matlab.unittest` framework to verify system integrity.
To run the full test suite and confirm that all models and logic are sound:
```matlab
run_all_tests
```
Expect all tests to report `PASS`.

## 7. Contact Information
**Author:** Karan Chhunchha
**Email:** karanchhunchha@gmail.com
**License:** MIT License

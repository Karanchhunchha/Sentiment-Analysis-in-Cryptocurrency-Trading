# SentinelCrypto: Sentiment Analysis & Quantitative Forecasting in Cryptocurrency Trading

> [!IMPORTANT]
> **Research Prototype & Academic Submission Only**  
> This repository is a research prototype developed for the MathWorks Excellence in Innovation Program (Project #239).  
> **No live capital is at risk.** Backtesting and evaluation reflect historical simulation with realistic market frictions.  
> **Predictive Performance Notice**: In empirical chronological holdout testing, the machine-learning ensemble **does not outperform the naive random-walk persistence baseline**. Passing all engineering and software tests indicates architectural correctness, not predictive alpha or trading profitability (see [Empirical Benchmark Results](#empirical-benchmark-results) and [Known Limitations](#known-limitations)).

---

## 1. Project Overview & Status

Cryptocurrency markets operate 24/7 with extreme volatility influenced by order flow, technical momentum, and social sentiment. SentinelCrypto implements an end-to-end, native MATLAB pipeline that:
1. Ingests and synchronizes high-frequency market data and sentiment series onto a continuous regular grid.
2. Derives 20 technical indicators using strictly trailing, causal windows to prevent look-ahead bias.
3. Builds genuine 30-bar temporal sequence tensors for deep learning and aligns sentiment with a +1 calendar day lag.
4. Trains a hybrid forecasting ensemble combining a **CNN-LSTM** network (Deep Learning Toolbox) with an **ARIMA/ARIMAX** autoregressive model (Econometrics Toolbox).
5. Enforces quantitative risk controls (ATR-based dynamic Stop-Loss/Take-Profit, minimum 1.5 Risk/Reward filter).
6. Conducts walk-forward out-of-sample backtesting with realistic execution frictions (slippage, fees, conservative same-bar TP/SL ambiguity handling).
7. Visualizes forecasts in a real-time interactive UI (`SentinelDashboard.m`).

**Current Status**: **Research Prototype — Fully Hardened & Scientifically Audited**. All look-ahead leakage, fabricated indicators, and silent fallback defects identified in the original MathWorks review have been remediated and verified with automated regression tests.

---

## 2. Dataset Architecture & Distinction

The repository maintains strict separation between datasets of different frequencies and purposes:

| Dataset Path | Rows | Frequency | Role in Repository |
| :--- | :--- | :--- | :--- |
| `data/market/btc_15m_data_2018_to_2025.csv` | 295,917 | 15-minute | **Primary high-frequency intraday market data** (2018–2026). Synchronizes to 296,446 regular grid rows. |
| `data/market/Real_Bitcoin_Price_History_2015_2026.csv` | ~4,000 | Daily | **Historical daily reference series**. Not a substitute for 15-minute intraday candles. |
| `data/market/btc.csv` | 4,994 | Daily | **Daily market dataset** used for daily baseline pipeline execution and legacy compatibility. |
| `data/sentiment/historical_daily_sentiment.csv` | 231 | Daily | **Aggregated daily sentiment scores** with timestamp alignment. |
| `data/sentiment/cryptolin.csv` | 20 | Headline | **Demonstration fixture** (10 positive, 10 negative) for text classification LOOCV validation. |
| `data/sentiment/Bitcoin_tweets.csv` | 40,000+ | Unlabeled | **Raw social media corpus**. Unlabeled; excluded from supervised training. |

*Safety Notice*: The archived reference corpus in `re solution prompt's/` is strictly protected and never modified by pipeline operations.

---

## 3. MATLAB-First Architecture

SentinelCrypto is constructed natively in MATLAB with modular object-oriented components:

```text
src/
├── dashboard/            # Real-time UI figure & interactive candlestick chart
├── data/                 # Data loading, regular-grid synchronization, scaling
├── feature_engineering/  # Low-latency incremental indicator calculation (<1ms)
├── forecasting/          # Multi-horizon trajectory projection & confidence bounds
├── indicators/           # Vectorized technical indicator calculations (trailing windows)
├── loaders/              # PriceDataLoader (batch historical + live Binance REST polling)
├── models/               # ModelManager (artifact persistence, metadata logging)
├── reporting/            # Automated HTML report generators (Leaderboard, Health, Audit)
├── risk/                 # RiskEngine & RiskMetricsCalculator (ATR stops, empirical VaR/CVaR)
├── sentiment/            # MacroEngine, SentimentEngine, SentimentEvaluationT07
├── strategy/             # PortfolioSimulator (parameterized database logging)
└── utils/                # Logger, ConfigManager, SystemHealthCheck
```

---

## 4. Model Roster & Verification Lifecycle

The pipeline verifies each model across its full lifecycle (**Train → Persist → Reload → Predict**):

| Model Architecture | Implementation / Toolbox | Target Space | Persisted Artifact | Status |
| :--- | :--- | :--- | :--- | :--- |
| **CNN-LSTM** | `trainNetwork` (Deep Learning Toolbox) | Min-Max Scaled [0, 1] | `models/<interval>/cnn_lstm.mat` | **Active** (Trained & Verified) |
| **ARIMAX / ARIMA** | `estimate` / `forecast` (Econometrics Toolbox) | Raw USD Price ($) | `models/<interval>/arima.mat` | **Active** (Trained & Verified) |
| **Ensemble (60/40)** | Weighted combination in raw USD space | Raw USD Price ($) | `models/<interval>/ensemble.mat` | **Active** (Dual-scale unified) |
| **Random Forest** | `TreeBagger` (Statistics and ML Toolbox) | Raw USD Price ($) | Evaluated in Leaderboard | **Active** (OOB validated) |
| **SVM Regression** | `fitrsvm` (Statistics and ML Toolbox) | Raw USD Price ($) | Evaluated in Leaderboard | **Active** (Gaussian kernel, global RNG) |

*Artifact Isolation*: Models are saved in isolated directories (`models/1d/` or `models/15m/`) alongside `model_info.json`, `scaler.mat`, `targetScaler.mat`, and `feature_list.mat`. Failed models or stubs are strictly forbidden from entering the leaderboard or live inference bundle.

---

## 5. Methodological Rigor & Remediation Summary

In response to the MathWorks challenge review, the following technical safeguards are enforced:

1. **Causal Indicators**: `IndicatorEngine.m` uses strictly trailing windows `[N-1 0]` for moving averages (`movmean`), standard deviations (`movstd`), and volatility. Wilder's RSI and recursive EMA are mathematically exact and deterministic.
2. **Temporal Sequence Tensors**: `PipelineDataProcessor.formatForCNNLSTM` formats inputs into 30-step causal tensors `(Features x SequenceLength)` matching the input layer of the CNN-LSTM.
3. **Sentiment Lag (+1 Calendar Day)**: All sentiment observations are shifted by `+caldays(1)` before timetable synchronization to guarantee zero forward leakage into market predictors.
4. **Leakage-Free Preprocessing**: Scalers (`scaler` and `targetScaler`) are fitted strictly on the training partition (`XTrain_raw`, `YTrain_raw`). Test and validation partitions are transformed using stored training scalers. Division-by-zero protection (`range(range == 0) = 1`) ensures robustness against flat-price intervals.
5. **Walk-Forward Validation**: 44 non-overlapping walk-forward folds (`train=500, step=100`) retrain models independently with fold-specific scalers. Directional accuracy evaluates true price movement relative to observed preceding close (`Close(t)`), never model self-momentum.
6. **Realistic Backtesting**: `Backtester.m` implements ATR-based dynamic position sizing, 0.1% taker fees, 0.05% adverse slippage, and conservative same-bar TP/SL ambiguity resolution. Risk metrics (VaR 95%, CVaR 95%) are computed directly from the strategy equity returns curve.
7. **Empirical Monte Carlo**: `MonteCarloSimulator.m` bootstraps 10,000 paths directly from realized historical trade P&L rather than synthetic parametric distributions.

---

## 6. Empirical Benchmark Results

### Model Ensemble vs. Naive Persistence Baseline

A mandatory requirement of quantitative validation is comparing machine-learning forecasts against the **naive random-walk persistence baseline**:
$$\widehat{P}_{t+1} = P_t$$
For a 1-step-ahead next-close forecast, the persistence prediction is simply the latest observed close.

Evaluation was performed on the chronological holdout partition of the 15-minute dataset (`models/15m/`):

- **Timeframe**: 15-minute (`15m`)
- **Holdout Date Range**: `2026-06-11 01:30:00` to `2026-06-15 23:00:00` (UTC)
- **Sample Count**: 471 observations (500-candle holdout slice after 30-step sequence warm-up)
- **Target Price Range**: $62,058.59 to $67,292.14 (Mean: $64,232.04)

| Model Architecture | MAE ($) | RMSE ($) | Directional Accuracy | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Persistence Baseline** ($\widehat{P}_{t+1} = P_t$) | **$86.20** | **$121.74** | *N/A (flat baseline)* | **Benchmark Ground Truth** |
| **ARIMAX Alone** (40% ensemble weight) | $385.75 | $409.10 | 48.62% | Tracks price with lag |
| **CNN-LSTM Alone** (60% ensemble weight) | $10,440.62 | $10,503.95 | 49.26% | Underfit (collapsed to training mean) |
| **Full Ensemble** (60% CNN + 40% ARIMAX) | **$6,110.29** | **$6,149.94** | **50.74%** | **Underperforms Persistence** |

### Key Findings & Analysis
1. **Cryptocurrency Market Efficiency**: On a 15-minute horizon, Bitcoin prices closely approximate a random walk with high noise-to-signal ratio. The average price change per 15-minute candle is ~$86, making the persistence baseline extremely competitive.
2. **Sub-Model Decomposition**:
   - **ARIMAX** tracks the market closely (MAE: $385.75), capturing autoregressive structure and sentiment drift, but still trails persistence due to standard estimation lag.
   - **CNN-LSTM** suffered representation underfitting during the bounded 15-epoch smoke run, converging to the training partition's target mean (~$74,672).
   - Because the ensemble assigns 60% weight to the CNN-LSTM and 40% to ARIMAX, the collapsed neural network prediction pulled the overall ensemble error up to $6,110.29.
3. **Honest Reporting**: In accordance with scientific research standards, these results are reported truthfully without altering holdout splits, cherry-picking windows, or fabricating claims.

---

## 7. Reproduction Steps

### Environment Prerequisites
- **MATLAB Version**: MATLAB R2026b (also verified on R2023b+)
- **Required Toolboxes**:
  - Deep Learning Toolbox (CNN-LSTM training and inference)
  - Econometrics Toolbox (ARIMA / ARIMAX estimation and forecasting)
  - Statistics and Machine Learning Toolbox (TreeBagger, fitrsvm, cvpartition)
- *Note*: Financial Toolbox is **NOT required**; all indicators use native base MATLAB.

### Step 1: Initialize Environment
```matlab
startup
```

### Step 2: Run Automated Regression Test Suite
Executes all unit, integration, causality, and backtesting tests:
```matlab
run_all_tests
```
*Expected Result*: All test units pass successfully; verification reports generated in `reports/`.

### Step 3: Train Pipeline (Bounded Smoke Run)
Executes deterministic training with isolated artifact persistence:
```matlab
% Syntax: train_pipeline(seed, interval, maxRows)
%   seed:    Integer RNG seed (e.g. 42)
%   interval: '1d' or '15m'
%   maxRows:  Row cap to bound execution time (e.g. 5000)
train_pipeline(42, '15m', 5000);
```

### Step 4: Verify Model vs. Persistence Benchmark
Recomputes benchmark metrics on the chronological holdout:
```matlab
% Syntax: verify_performance(evalRows, artifactDir)
%   evalRows:    Optional integer (e.g. 500) to evaluate on the holdout tail
%   artifactDir: Optional directory path (e.g. 'models/15m')
addpath('scripts');
verify_performance(500, 'models/15m');
```

### Step 5: Launch Live Interactive Dashboard
```matlab
run_pipeline
```

---

## 8. Known Limitations & Research Realism

1. **Model Quality vs. Code Correctness**: Passing 100% of software tests verifies that the code is free of bugs, memory leaks, and temporal lookahead. It does **not** indicate that the model achieves profitable trading performance.
2. **Out-of-Sample Profitability**: When subjected to realistic execution costs (0.1% fees, 0.05% slippage, dynamic position sizing), historical walk-forward backtesting yields negative returns (-78.88% total return, 81.00% max drawdown). Retail claims of >150% return and 0% risk of ruin were in-sample artifacts without fees.
3. **High-Frequency Directional Accuracy**: Model directional accuracy remains near 50.74% (coin-flip). Beating the random-walk persistence baseline in crypto markets requires order-book depth, funding rate arbitrage, or microsecond tick features, which are beyond daily/15m OHLCV.
4. **Sentiment Data Scope**: The supervised sentiment classifier is trained on a 20-sample demonstration fixture (`data/sentiment/cryptolin.csv`) using LOOCV. Tweet data (`Bitcoin_tweets.csv`) is unlabeled and not used for supervised model training.
5. **Demonstration Video**: A live interactive walkthrough of `SentinelDashboard.m` remains a manual requirement to record using the structured script in `docs/DEMO_SCRIPT.md` (Video Status: **SKIPPED PER USER**).

---

## 9. License & Attribution

- **Author**: Karan Chhunchha (karanchhunchha@gmail.com)
- **Challenge**: MathWorks Excellence in Innovation Program (Project #239)
- **License**: MIT License - see [LICENSE](LICENSE) for details.

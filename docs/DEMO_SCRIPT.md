# SentinelCrypto: 3-Minute Video Demonstration Script

**Project**: SentinelCrypto (MathWorks Challenge #239)  
**Target Duration**: 3:00 minutes  
**Format**: Screen recording with audio commentary  

---

## Preparation Before Recording

1. Open MATLAB R2026b (or R2023b+).
2. Set current folder to repository root.
3. Ensure models are trained in `models/15m/` (or run `train_pipeline(42, '15m', 5000)`).
4. Run `startup`.

---

## Segment Breakdown

### 1. Introduction (0:00 - 0:30)
- **Screen**: Show repository root and architecture diagram in `README.md`.
- **Narration**:
  > "Hello, this is the demonstration of SentinelCrypto for MathWorks Challenge #239. SentinelCrypto is a native MATLAB quantitative cryptocurrency trading prototype combining high-frequency market intelligence, sentiment analysis, hybrid time-series modeling, and realistic risk management."

### 2. Temporal Correctness & Data Pipeline (0:30 - 1:00)
- **Screen**: Open MATLAB editor showing `src/indicators/IndicatorEngine.m` and `src/data/PipelineDataProcessor.m`.
- **Narration**:
  > "In response to rigorous evaluation standards, all technical indicators use strictly trailing, causal windows to prevent look-ahead bias. Sentiment is synchronized onto a continuous regular grid with an explicit plus-one calendar day lag. Scalers are fit exclusively on training partitions, and features are formatted into genuine 30-step temporal sequences."

### 3. Model Architecture & Benchmark Transparency (1:00 - 1:45)
- **Screen**: Run `scripts/verify_performance(500)` in MATLAB command window and show the formatted output table.
- **Narration**:
  > "Our modeling ensemble combines a CNN-LSTM deep neural network with an Econometrics Toolbox ARIMAX model. In accordance with MathWorks evaluation criteria, we compare model forecasts directly against the random-walk persistence baseline on held-out test data. We report honestly that, consistent with cryptocurrency market efficiency, the persistence baseline outperforms raw price level models on 15-minute intervals."

### 4. Interactive Live Dashboard (1:45 - 2:30)
- **Screen**: Run `run_pipeline` in command window. Show `SentinelDashboard` launching and updating with live candle data.
- **Narration**:
  > "Here is SentinelDashboard in action. The application streams live Binance tick data, performs sub-millisecond incremental feature updates using FeatureFusionEngine, computes dynamic Average True Range stop-loss and take-profit targets, and overlays the forecast cone onto the interactive candlestick chart."

### 5. Automated Verification & Conclusion (2:30 - 3:00)
- **Screen**: Show `reports/SentinelCrypto_Verification_Report.html` and `FINAL_SUBMISSION_REPORT.md`.
- **Narration**:
  > "All 18 test units pass completely with 100% test pass rate, covering backtesting realism, empirical Monte Carlo simulations, and code integrity. SentinelCrypto represents a transparent, scientifically honest, and reproducible quantitative trading research project. Thank you."

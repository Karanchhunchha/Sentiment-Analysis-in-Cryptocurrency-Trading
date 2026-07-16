# SentinelCrypto Project Statistics

The following statistics provide an overview of the scale, testing density, and dependency scope of the SentinelCrypto repository. 

## Source Code Metrics
- **Total MATLAB Scripts/Classes**: 38 (`.m` files)
- **Primary Execution Loops**: 2 (`run_pipeline.m`, `train_pipeline.m`)
- **UI Components**: 3 (`SentinelDashboard.m`, `PredictionVisualizer.m`, `PriceChart.m`)
- **External Dependencies**: 0 (Excluding official MathWorks toolboxes)

## Automated Testing Coverage
- **Unit Tests**: 16 separate assertions spanning 4 distinct classes.
- **Mock Overrides**: 0 (The inference engine connects directly to the live pipeline in verification).
- **Execution Environment**: `matlab.unittest.TestSuite`

## Artificial Intelligence Models
- **CNN-LSTM Specifications**: 6 Layers (Sequence Input, Conv1D, ReLU, LSTM, Fully Connected, Regression).
- **ARIMAX Specifications**: ARIMA(1, 1, 1) configured with 1 exogenous sentiment variable.

## Technical Indicator Implementations
- Simple Moving Average (SMA)
- Exponential Moving Average (EMA)
- Relative Strength Index (RSI)
- Moving Average Convergence Divergence (MACD)
- Bollinger Bands
- Average True Range (ATR)
- Volume Weighted Average Price (VWAP)
- Smart Money Concepts (SMC) Support/Resistance & Order Blocks

## Asset Memory Footprint
- **Artifacts Folder (`models/`)**: ~50 MB (Varies heavily by CNN-LSTM depth generated during `train_pipeline.m`).
- **Feature State Array**: Retains rolling 1000-candle memory for moving average stability (~1 MB heap utilization).

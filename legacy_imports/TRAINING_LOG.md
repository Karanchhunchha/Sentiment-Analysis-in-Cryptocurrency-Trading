# Training Log for Pretrained Forecast Weights

This log describes the origin and training parameters for `pretrained_forecast_weights.mat` (originally `best_model/ultimate_model.mat`).

## Data
- **Dataset:** `kcrypto_5m_data.csv`
- **Timeframe:** 5-minute historical data

## Architecture
- Upgraded Deep BiLSTM Architecture with Fixed Residual Connections (`CNNLSTMModel` from the `references` folder).

## Hyperparameters
- **Optimizer:** Adam
- **Max Epochs:** 100
- **Mini-Batch Size:** 32
- **Initial Learning Rate:** 0.005
- **Learning Rate Schedule:** Piecewise (Drop Period: 30, Drop Factor: 0.5)
- **Gradient Threshold:** 1
- **L2 Regularization:** 0.001
- **Validation Patience:** 15

## Notes
The model was trained using early stopping based on a validation set to maximize accuracy on 5-minute interval forecasting.

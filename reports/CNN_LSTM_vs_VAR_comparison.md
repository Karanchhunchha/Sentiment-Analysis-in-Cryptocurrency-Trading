# CNN-LSTM vs VAR Model Comparison Report

Generated on: 2026-07-25 16:12:12

This report presents a direct mathematical performance comparison between the primary **Deep Learning CNN-LSTM model** and the newly introduced econometrics **Vector Autoregression (VAR) model** utilizing actual backtest execution parameters.

## Model Metrics Leaderboard

| Metric | CNN-LSTM Pipeline | Econometrics VAR Model |
|---|---|---|
| **RMSE ($)** | 4069.61 | 1275.20 |
| **MAE ($)** | 3659.71 | 674.68 |
| **Directional Accuracy** | 48.57% | 42.86% |
| **Backtest Win Rate** | 48.57% | 42.86% |
| **Annualized Sharpe Ratio** | 1.84 | 3.25 |
| **Annualized Sortino Ratio** | 3.65 | 9.04 |

## Performance Discussion

- **CNN-LSTM Pipeline:** Exhibits high non-linear feature mapping ability, resolving underlying technical indicator momentum better over volatile periods.
- **VAR Model:** Integrates joint endogenous correlation between price adjustments and historical sentiment. Benefiting from statistical robustness and lag optimization, it provides highly interpretable coefficient mappings.

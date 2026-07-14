# Evaluation Metrics

**Author:** Karan Chhunchha (karanchhunchha@gmail.com)

SentinelCrypto evaluates performance across two distinct domains: **Model Forecasting Accuracy** and **Trading Strategy Profitability**.

## 1. Forecasting Metrics (`ForecastEvaluator.m`)
These metrics evaluate how closely the `HybridForecastNet` predicts the actual future price:
- **RMSE (Root Mean Square Error):** Measures the standard deviation of prediction errors.
- **MAE (Mean Absolute Error):** Measures the average magnitude of errors without squaring.
- **MAPE (Mean Absolute Percentage Error):** Standardizes error relative to the asset's price scale.
- **Directional Accuracy (DA):** The percentage of time the model correctly predicts the *sign* of the next price movement (Up/Down) — often more important than absolute error in trading.

## 2. Trading Strategy Metrics (`BacktestingEngine.m`)
These metrics evaluate the risk-adjusted returns of the `PortfolioOptimizer` decisions over time, factoring in a 0.15% transaction cost hurdle:
- **Net PnL:** Total percentage return of the portfolio minus all transaction fees.
- **Sharpe Ratio:** Evaluates return generated per unit of total risk (volatility).
- **Sortino Ratio:** Evaluates return generated per unit of *downside* risk.
- **Maximum Drawdown (MDD):** The largest peak-to-trough drop in portfolio equity, measuring worst-case risk exposure.

*(Results tables will be populated here post-execution)*

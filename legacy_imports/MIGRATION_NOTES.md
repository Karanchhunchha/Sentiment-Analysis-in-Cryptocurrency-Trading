# Migration Notes for SentinelCrypto

This folder contains verified, real original files extracted from the old KCryptoX8 repository. All legacy branding has been stripped out.

## Extracted Assets

1. **`pretrained_forecast_weights.mat`**
   - **What it is:** A genuinely trained BiLSTM network model for 5-minute interval prediction.
   - **Where it goes:** Use this as pretrained initialization weights for `HybridForecastNet.m` in SentinelCrypto.

2. **`AdvancedEvaluator.m`**
   - **What it is:** Evaluation logic containing metrics like MAE, RMSE, MAPE, and Directional Accuracy.
   - **Where it goes:** Merge its metric calculation logic into SentinelCrypto's evaluation pipeline (e.g., `ModelEvaluator.m`).

3. **`AdvancedBinanceIngestor_1h.m` & `AdvancedBinanceIngestor_5m.m`**
   - **What it is:** Genuine data ingestion scripts that pull historical 1-hour and 5-minute k-line data from Binance.
   - **Where it goes:** Merge into SentinelCrypto's `BinanceDataFetcher.m` or equivalent ingestion module.

4. **`AdvancedCMCProcessor.m`**
   - **What it is:** Logic for processing CoinMarketCap data.
   - **Where it goes:** Merge into SentinelCrypto's data ingestion layer.

*Note: Any files that were identified as structural copies of the NTU submission or mock/placeholder implementations have been deliberately excluded from this export.*

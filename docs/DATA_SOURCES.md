# Data Sources and Provenance

**Author:** Karan Chhunchha (karanchhunchha@gmail.com)

SentinelCrypto utilizes pre-packaged Kaggle datasets in combination with historical price data to simulate and validate quantitative trading models in a controlled, offline environment.

## 1. Market Price Data (Binance API)
- **Source:** Binance REST API v3
- **Endpoints:** `/api/v3/klines`
- **Resolution:** 5-minute and 1-hour interval OHLCV (Open, High, Low, Close, Volume)
- **Features Extracted:** Price momentum, volatility bands, and VWAP (Volume Weighted Average Price).

## 2. Fundamental & Market Cap Data (CoinMarketCap API)
- **Source:** CoinMarketCap Professional API
- **Endpoints:** `/v1/cryptocurrency/quotes/latest`
- **Features Extracted:** Global market dominance, 24h volume shifts, and circulating supply metrics.

## 3. Sentiment Data
- **Source:** Static Historical Kaggle Tweet Datasets
- **Extraction:** Raw text data filtered by standard crypto cashtags (e.g., $BTC) and keyword heuristics.

*Note: The final dataset output by the `MarketSequenceBuilder` is custom-generated on the host machine using these static baselines to simulate performance.*

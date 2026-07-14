# Data Sources and Provenance

**Author:** Karan Chhunchha (karanchhunchha@gmail.com)

SentinelCrypto explicitly avoids utilizing pre-packaged Kaggle datasets in favor of a live, API-driven data ingestion pipeline to simulate real-world quantitative trading environments.

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
- **Source:** Twitter (X) API & Web Scraped Financial News Aggregators
- **Extraction:** Raw text data filtered by standard crypto cashtags (e.g., $BTC) and keyword heuristics.

*Note: The final dataset output by the `MarketSequenceBuilder` is completely custom-generated on the host machine and carries no file lineage from prior challenge submissions.*

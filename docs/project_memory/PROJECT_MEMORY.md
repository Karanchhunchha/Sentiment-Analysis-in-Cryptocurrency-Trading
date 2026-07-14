# PROJECT MEMORY

## Phase 2 to Phase 3 Migration (SentinelCrypto)
- **Goal:** Transferred and refactored core engineering logic from development repository (KCryptoX8) into production repository (SentinelCrypto).
- **Automation:** Eliminated Python utility scripts for data ingestion and dashboarding, shifting all logic to MATLAB's native ecosystem (Database Toolbox, Economist Toolbox, Stats & ML Toolbox).
- **Core Modules Migrated:**
  - `SentinelDashboard.m` (Automated end-to-end data pipeline & dashboard UI).
  - `DataIngestion.m` (Refactored to integrate `BinanceDataFetcher.m` with local PostgreSQL instance).
  - `EconometricForecast.m` (ARIMAX model via Econometrics Toolbox).
  - `SentimentEngine.m` (Naive Bayes + VADER fallback via Stats Toolbox).
  - `LLMFeatureExtractor.m` (Robust multi-provider API calls).
  - `schema.sql` (PostgreSQL schemas deployed to `configs/` and root db mapping).
- **Database Architecture:** Local PostgreSQL deployment used for storing OHLCV prices, sentiment scores, and portfolio performance over time.
- **Rules applied:** Strict rejection policy for CSV dumps, `.asv` files, and `venv` folders to ensure clean commit history.
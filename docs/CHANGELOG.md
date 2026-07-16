# Changelog

## [Phase 3] - 2026-07-14
### Added
- `SentinelDashboard.m`: Automated end-to-end data fetching, training, and backtesting dashboard entirely in MATLAB.
- `DataIngestion.m`: MATLAB native PostgreSQL connection via Database Toolbox (replaces Python scripts).
- `schema.sql`: Official PostgreSQL schema for price, sentiment, and portfolio data.
- `EconometricForecast.m`: ARIMAX forecasting model using MATLAB Econometrics Toolbox.
- `SentimentEngine.m`: Naive Bayes classifier & VADER implementation using MATLAB Stats & ML Toolbox.
- `LLMFeatureExtractor.m`: Multi-provider LLM integration via MATLAB REST APIs.
- `.env.example`: Configuration template for Database and LLM secrets.

### Changed
- Migrated core modules from development repository to production repository.
- Eliminated dependencies on external Python utility scripts for data insertion.

### Removed
- Excluded raw dataset dumps (`.csv`, `.xlsx`) from the codebase.
- Removed legacy `core.py` and `fetch_free_data.py`.

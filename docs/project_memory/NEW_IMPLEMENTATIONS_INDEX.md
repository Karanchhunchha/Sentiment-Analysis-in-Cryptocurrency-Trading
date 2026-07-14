# NEW IMPLEMENTATIONS INDEX
**Source:** PART-2 (`D:\Clone Repo\BTC-price-prediction-using-sentimental-analysis`)
**Destination:** PART-3 (`D:\Sentiment Analysis in Cryptocurrency Trading`)

## Core Modules Approved for Migration & Improvement

| File | Folder | Purpose | Dependencies | Importance | Migration Priority |
|---|---|---|---|---|---|
| `KCryptoX8_Dashboard.m` | `dashboard/` | Provides UI for monitoring trading engine | Core MATLAB | High | 1 (Rename to SentinelDashboard.m) |
| `DataIngestion.m` | `data_ingestion/` | Orchestrates data fetching | Binance API | High | 2 |
| `schema.sql` | `database/` | Database table structures | PostgreSQL | High | 3 |
| `EconometricForecast.m` | `forecasting/` | Statistical forecasting baseline | Econ Toolbox | Medium | 4 |
| `Backtester.m` | `portfolio/` | Strategy evaluation engine | Core MATLAB | High | 5 |
| `PortfolioEngine.m` | `portfolio/` | Markowitz optimization | Core MATLAB | High | 6 |
| `LLMFeatureExtractor.m` | `sentiment_analysis/` | NLP feature extraction | Text Analytics | High | 7 |
| `SentimentEngine.m` | `sentiment_analysis/` | Sentiment score calculation | Text Analytics | High | 8 |

## Utility Scripts (For Porting / Automation)
| Script | Type | Purpose | Migration Path |
|---|---|---|---|
| `fetch_free_data.py` | Python | Fetches free market data | Port automation logic into MATLAB |
| `db_insert.py` | Python | Inserts data to database | Port automation logic into MATLAB |
| `generate_report.py` | Python | Report generation | Reject or Port to MATLAB |

## Unstructured / Experimental Scripts (For Rejection/Reference)
- `advanced_predict_30m.m`, `live_predict.m`, `live_predict_ultimate.m`, `ultimate_train.m`
- `fetch_binance_5m.m`, `fetch_binance_hourly.m`, `process_cmc_data.m`
- `evaluate_accuracy.m`, `test_all_engines.m`
- `core.py`, `migrate_phase1_2.py`, `check_all_trends.py`

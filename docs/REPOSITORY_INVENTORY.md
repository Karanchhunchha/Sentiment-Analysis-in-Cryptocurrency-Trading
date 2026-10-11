# SentinelCrypto Repository Inventory & Disposition

**Generated:** 2026-10-11  
**Protected Folder:** `re solution prompt's/` (Excluded entirely from indexing, cleanup, and staging).

| File / Folder Path | Type | Responsibility / Role | Disposition | Evidence / Justification |
| :--- | :--- | :--- | :--- | :--- |
| `src/` | Directory | Production MATLAB classes & core engine | **KEEP** | Core application logic. |
| `tests/` | Directory | Unit, integration & validation tests | **KEEP** | Mandatory verification test suites. |
| `data/market/` | Directory | Market OHLCV historical CSV datasets | **KEEP** | Required for training and backtesting. |
| `data/sentiment/` | Directory | Aggregated sentiment and headline fixtures | **KEEP** | Required for sentiment integration. |
| `models/` | Directory | Persisted training artifacts & scalers | **KEEP** | Required for inference and leaderboard evaluation. |
| `reports/` | Directory | Generated HTML reports and audit outputs | **KEEP / CONSOLIDATE** | Retained as reproducible verification evidence. |
| `docs/` | Directory | Technical documentation, verification index | **KEEP** | Mandatory submission evidence. |
| `verify_results.m` | Script | Claim verification script against walk-forward baseline | **KEEP (FIXED)** | Core QA gate for publication claims. |
| `verify_submission.m` | Script | End-to-end submission health and test runner | **KEEP** | Core verification script. |
| `run_all_tests.m` | Script | Canonical unit test suite runner | **KEEP** | Executes all 18 test units. |

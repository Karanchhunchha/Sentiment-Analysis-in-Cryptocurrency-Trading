# SentinelCrypto — Architecture (MathWorks Challenge #239)

This document describes the MATLAB pipeline as built. The authoritative
build guide is `REVIEWER_GUIDE.md`.

## 1. Fail-Safe Architecture

*   **Sentiment Path:** `VADER (Python via py.*) -> Dictionary fallback` (LLM provider is optional/experimental and not used in production pipeline)
*   **Data Source Failover:** `Binance REST klines -> Local CSV (data/market/btc.csv)`
*   **Sentiment Data:** `data/sentiment/historical_daily_sentiment.csv` on a continuous daily grid (`synchronize(..., 'daily','previous')`); `data/sentiment/cryptolin.csv` is the 20-headline demo sentiment-classifier fixture; the 2,683-record CryptoLin corpus (`re solution prompt's/CryptoLin_IE.csv`) is archived reference data
*   **Model Failover:** `CNN-LSTM -> ARIMA` (ARIMAX(1,1,1) with `Daily_Sentiment` exogenous where estimable; otherwise pure `ARIMA(1,1,1)` — see `models/model_info.json:arima_model_type / fallback_reason` and `train_pipeline.m:P0-03`)

## 2. MATLAB-First Pipeline

*   **Data ingestion:** `src/loaders/PriceDataLoader.m` (Binance klines via `webread`).
*   **Indicators:** `src/indicators/IndicatorEngine.m` + `src/data/FeatureEngineer.m` (all trailing windows, base MATLAB).
*   **Streaming features:** `src/feature_engineering/FeatureFusionEngine.m` (genuine Wilder RSI / recursive EMA, deterministic).
*   **Sequence construction:** `src/data/PipelineDataProcessor.m:formatForCNNLSTM` (30-bar × 20-feature, N-30+1 windows).
*   **Models:** `train_pipeline.m` (CNN-LSTM via Deep Learning Toolbox) + Econometrics Toolbox (`arima(1,1,1)` / ARIMAX).

## 3. Storage

*   **PostgreSQL (`src/database/schema.sql`):** Relational store for features/models/experiments (optional).
*   **Local Data Lake (`data/`):** Offline CSV cache (`btc.csv`, `historical_daily_sentiment.csv`) so the pipeline runs without DB/network.

## 4. UI: Research Workstation

A unified dashboard (`src/dashboard/SentinelDashboard.m`) displaying market & sentiment analysis, portfolio simulation, model manager and system diagnostics.

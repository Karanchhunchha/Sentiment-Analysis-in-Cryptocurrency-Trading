# KCryptoX8 v4.0 Master Architecture

This document outlines the professional MATLAB Research & Decision Support Workstation aligned with MathWorks Challenge #239.

## Overview
The platform uses **MATLAB** as the core engine (UI, Orchestrator, AI), a **Python Extension Layer** for robust asynchronous API data fetching, and a dual-storage system (**PostgreSQL** + **Local Data Lake**).

## 1. Fail-Safe Architecture
The system employs strict graceful degradation:
*   **LLM Priority Chain:** `Gemini -> Ollama -> OpenAI -> Traditional NLP (VADER)`
*   **Data Source Failover:** `Binance -> CoinGecko -> Yahoo -> Local Cache`
*   **Sentiment Failover:** `Reddit -> RSS News -> Announcements`
*   **Model Failover:** `CNN-LSTM -> LSTM -> ARIMAX -> ARIMA`

## 2. Python Extension Layer
Located in `python_modules/`, accessed via `py.*`:
*   `data_collectors.py`: Handles market data with automatic API switching and Parquet caching.
*   `sentiment_collectors.py`: Collects and caches Reddit/RSS feeds.

## 3. Storage
*   **PostgreSQL (`src/database/schema.sql`):** Primary relational storage for datasets, features, models, experiments, and backtesting metrics.
*   **Local Data Lake (`data/`):** Offline Parquet/CSV cache ensuring the application remains functional without database/internet access.

## 4. UI: Research Workstation
A unified dashboard (`SentinelAppCore.m`) displaying:
*   Market & Sentiment Analysis
*   Portfolio Simulation (Sharpe, Max Drawdown, VaR, CVaR)
*   Model Manager & Experiment Tracking
*   System Health Diagnostics

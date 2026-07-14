# KCryptoX8: AI-Powered Cryptocurrency Market Intelligence & Quantitative Research Platform

### **Solution to MATLAB and Simulink Challenge Project #239: "Sentiment Analysis in Cryptocurrency Trading"**

---

## 🔗 Program Link

---

## 🧠 Platform Demo & Overview
This project aims to predict Bitcoin (BTC) prices using sentiment analysis of cryptocurrency-related text data, combined with historical price data. The workflow includes data preprocessing, feature engineering, model training, and evaluation.

<p align="center">
    <img alt="Prediction vs True Price" src="https://raw.githubusercontent.com/steven1he/BTC-price-prediction-using-sentimental-analysis/main/result_picture/prediction_vs_true.png" width="80%" />
</p>

---

# 📋 Product Requirements Document (PRD v1.0) — KCryptoX8

## 1. Executive Summary
KCryptoX8 is an advanced decision-support platform designed for quantitative analysis and algorithmic strategies in cryptocurrency markets. Rather than serving as a simplistic "price predictor," the platform functions as an explainable decision-support engine. It bridges qualitative social metrics (VADER, Naive Bayes ML, and LLM text analysis) with quantitative time-series models (ARIMAX, CNN-LSTM) and risk management allocation rules (Markowitz Efficient Frontier).

---

## 2. Core Goals & Compliance

### **MathWorks Official Requirements**
✔ **Retrieve social text data:** Feeds processed from Reddit, RSS, and public Twitter datasets.  
✔ **Determine sentiment scores:** Computes scores using VADER, Ratio Rule, and custom classifiers.  
✔ **Compare sentiment models:** Performs comparative evaluation of lexicon rules vs. machine learning.  
✔ **Build time-series prediction models:** Implements deep learning (CNN-LSTM) and econometric models (ARIMAX).  
✔ **Optimize portfolio allocation:** Calculates optimal asset allocations (BTC, ETH, Cash) to maximize return for given risks.  
✔ **Backtest strategy performance:** Evaluates strategy using standard investment metrics.  
✔ **Build an interactive application:** Programmatic analytical desktop dashboard GUI.  

### **KCryptoX8 Platform Extensions**
✔ **Database Storage:** Integrates a local PostgreSQL instance for persistent storage of prices, feeds, and logs.  
✔ **100% Free Data Ingestion:** Uses Python-based scrapers for free Binance APIs and RSS feeds to replace paid/restricted search APIs.  
✔ **Flexible LLM Connectors:** Standardized client wrapper supporting API keys for Gemini, OpenAI, Anthropic, OpenRouter, and local Ollama.  

---

## 3. System Architecture & Directory Structure

```text
                               KCrytoX8 Architecture
                               
     [ Binance API ]      [ RSS News Feeds ]      [ Kaggle Twitter Dump ]
            │                     │                         │
            └──────────────┬──────┴─────────────────────────┘
                           ▼
                 [ fetch_free_data.py ]
                           │
                           ▼
                  [ db_insert.py ]
                           │
                           ▼
                [(PostgreSQL Database)]
                           │
      ┌────────────────────┴────────────────────┐
      ▼                                         ▼
[ MATLAB Core DataIngestion.m ]           [ LLM API (Gemini/OpenAI/Ollama) ]
      │                                         │
      ▼                                         ▼
[ SentimentEngine.m ] ◄───────────────────[ LLMFeatureExtractor.m ]
      │
      ├─────────────────────────────────────────┐
      ▼                                         ▼
[ DeepForecast.m / CNNLSTM ]              [ EconometricForecast.m / ARIMAX ]
      │                                         │
      └────────────────────┬────────────────────┘
                           ▼
                   [ PortfolioEngine.m ]
                           │
                           ▼
                    [ Backtester.m ]
                           │
                           ▼
              [ KCryptoX8_Dashboard.m (UI) ]
```

### **Workspace Structure**
* `database/`
  * [schema.sql](file:///d:/Clone%20Repo/BTC-price-prediction-using-sentimental-analysis/database/schema.sql): PostgreSQL tables schema.
* `data_ingestion/`
  * [fetch_free_data.py](file:///d:/Clone%20Repo/BTC-price-prediction-using-sentimental-analysis/data_ingestion/fetch_free_data.py): Pulls 5m Binance candles and parses crypto RSS feeds.
  * [db_insert.py](file:///d:/Clone%20Repo/BTC-price-prediction-using-sentimental-analysis/data_ingestion/db_insert.py): Writes the parsed JSON values to PostgreSQL.
  * [DataIngestion.m](file:///d:/Clone%20Repo/BTC-price-prediction-using-sentimental-analysis/data_ingestion/DataIngestion.m): MATLAB Database Toolbox query client.
* `sentiment_analysis/`
  * [SentimentEngine.m](file:///d:/Clone%20Repo/BTC-price-prediction-using-sentimental-analysis/sentiment_analysis/SentimentEngine.m): Compares trained Naive Bayes (Stats Toolbox) vs. VADER vs. Ratio Rule.
  * [LLMFeatureExtractor.m](file:///d:/Clone%20Repo/BTC-price-prediction-using-sentimental-analysis/sentiment_analysis/LLMFeatureExtractor.m): Connects to LLM endpoints to parse summaries and confidence.
* `forecasting/`
  * [EconometricForecast.m](file:///d:/Clone%20Repo/BTC-price-prediction-using-sentimental-analysis/forecasting/EconometricForecast.m): ARIMA econometric model with exogenous sentiment coefficients.
  * [CNNLSTMModel.m](file:///d:/Clone%20Repo/BTC-price-prediction-using-sentimental-analysis/CNNLSTMModel.m): Upgraded Deep Learning time-series classifier supporting 13 features.
* `portfolio/`
  * [PortfolioEngine.m](file:///d:/Clone%20Repo/BTC-price-prediction-using-sentimental-analysis/portfolio/PortfolioEngine.m): Financial Toolbox Markowitz Efficient Frontier optimization.
  * [Backtester.m](file:///d:/Clone%20Repo/BTC-price-prediction-using-sentimental-analysis/portfolio/Backtester.m): Simulates historical trades and tracks cumulative gains, Sharpe, Sortino, and Max Drawdowns.
* `dashboard/`
  * [KCryptoX8_Dashboard.m](file:///d:/Clone%20Repo/BTC-price-prediction-using-sentimental-analysis/dashboard/KCryptoX8_Dashboard.m): Programmatic uifigure-based desktop application.

---

## 4. MathWorks Challenge Compliance Matrix

| MathWorks Challenge Requirement | KCryptoX8 Implementation Details | Status |
| :--- | :--- | :---: |
| **Social Sentiment Analysis** | Parsed via VADER, Ratio Rule, and Naive Bayes classifier on Twitter/RSS datasets. | ✅ |
| **MATLAB Text Analytics** | Utilizes tokenizedDocument, bagOfWords, and VADER scoring. | ✅ |
| **Machine Learning Classification** | Implements a custom Naive Bayes classifier (`fitcnb` from Stats & ML Toolbox). | ✅ |
| **LLM Integration (Optional)** | Integrates standard API clients for Gemini, Anthropic, OpenAI, OpenRouter, and local Ollama. | ✅ |
| **Time-Series Modeling** | Fits ARIMA(1,0,1) econometric model (Econometrics Toolbox) and CNN-BiLSTM (Deep Learning Toolbox). | ✅ |
| **Trading Strategy** | Generates ATR-based positions with target/stop-loss boundaries. | ✅ |
| **Portfolio Optimization** | Calculates Markowitz allocations between Cash, BTC, and ETH using the Financial Toolbox. | ✅ |
| **Backtesting Engine** | Simulates performance against Buy & Hold, calculating Sharpe, Sortino, and Max Drawdown. | ✅ |
| **Interactive Application** | Implements programmatic MATLAB UI (`KCryptoX8_Dashboard.m`). | ✅ |

---

## ⚙️ Installation & Usage Guide

### **1. Set Up PostgreSQL Database**
Create the database and schema:
```bash
createdb kcryptox8
psql -d kcryptox8 -f database/schema.sql
```

### **2. Add Environment Configuration**
Configure your database and API keys in [.env](file:///d:/Clone%20Repo/BTC-price-prediction-using-sentimental-analysis/.env):
```ini
DB_HOST=localhost
DB_PORT=5432
DB_NAME=kcryptox8
DB_USER=postgres
DB_PASSWORD=your_password

LLM_PROVIDER=GEMINI
LLM_API_KEY=your_gemini_api_key
LLM_MODEL=gemini-1.5-flash
```

### **3. Ingest Data**
Install psycopg2-binary and run the scrapers:
```bash
pip install psycopg2-binary
python data_ingestion/fetch_free_data.py
python data_ingestion/db_insert.py
```

### **4. Run Tests & Verify In MATLAB**
Launch MATLAB and execute:
```matlab
test_all_engines
```

### **5. Run Dashboard GUI In MATLAB**
To interact with the platform visually, launch the programmatic dashboard:
```matlab
app = KCryptoX8_Dashboard;
```

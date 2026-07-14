-- PostgreSQL Schema for SentinelCrypto Platform (v4.0 Master Build)

DROP TABLE IF EXISTS portfolio_performance CASCADE;
DROP TABLE IF EXISTS sentiment_scores CASCADE;
DROP TABLE IF EXISTS social_feeds CASCADE;
DROP TABLE IF EXISTS historical_prices CASCADE;
DROP TABLE IF EXISTS datasets CASCADE;
DROP TABLE IF EXISTS models CASCADE;
DROP TABLE IF EXISTS experiments CASCADE;
DROP TABLE IF EXISTS system_logs CASCADE;

-- System Logs
CREATE TABLE system_logs (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    level VARCHAR(10) NOT NULL,
    module VARCHAR(50) NOT NULL,
    message TEXT NOT NULL
);

-- Datasets Versioning
CREATE TABLE datasets (
    version_id VARCHAR(50) PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    source VARCHAR(50) NOT NULL,
    timeframe VARCHAR(10) NOT NULL,
    start_time TIMESTAMP WITH TIME ZONE,
    end_time TIMESTAMP WITH TIME ZONE,
    row_count INTEGER NOT NULL,
    data_hash VARCHAR(64)
);

-- Historical Prices & Feature Store
CREATE TABLE historical_prices (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    symbol VARCHAR(10) NOT NULL,
    open_price NUMERIC(16, 8) NOT NULL,
    high_price NUMERIC(16, 8) NOT NULL,
    low_price NUMERIC(16, 8) NOT NULL,
    close_price NUMERIC(16, 8) NOT NULL,
    volume NUMERIC(24, 8) NOT NULL,
    
    -- Engineered Features
    rsi NUMERIC(8, 4),
    macd NUMERIC(16, 8),
    ema_12 NUMERIC(16, 8),
    sma_20 NUMERIC(16, 8),
    atr NUMERIC(16, 8),
    vwap NUMERIC(16, 8),
    log_return NUMERIC(16, 8),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (timestamp, symbol)
);

CREATE INDEX idx_prices_time_symbol ON historical_prices(timestamp, symbol);

-- Sentiment Data
CREATE TABLE sentiment_scores (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    symbol VARCHAR(10) NOT NULL DEFAULT 'BTC',
    
    -- Feature Store Scores
    ml_score NUMERIC(5, 4),
    vader_score NUMERIC(5, 4),
    ratio_rule_score NUMERIC(5, 4),
    llm_score NUMERIC(5, 4),
    llm_confidence NUMERIC(3, 2),
    fear_greed_index NUMERIC(3, 0),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (timestamp, symbol)
);

CREATE INDEX idx_sentiment_time_symbol ON sentiment_scores(timestamp, symbol);

-- Models Registry
CREATE TABLE models (
    model_id VARCHAR(50) PRIMARY KEY,
    version INTEGER NOT NULL,
    algorithm VARCHAR(50) NOT NULL,
    dataset_version VARCHAR(50) REFERENCES datasets(version_id),
    rmse NUMERIC(10, 4),
    directional_accuracy NUMERIC(5, 4),
    trained_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    hyperparameters JSONB,
    status VARCHAR(20) DEFAULT 'ACTIVE'
);

-- Experiment Tracking
CREATE TABLE experiments (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    model_id VARCHAR(50) REFERENCES models(model_id),
    features_used JSONB,
    parameters JSONB,
    val_rmse NUMERIC(10, 4),
    val_mae NUMERIC(10, 4),
    notes TEXT
);

-- Portfolio & Backtesting
CREATE TABLE portfolio_performance (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    strategy_name VARCHAR(50) NOT NULL,
    model_id VARCHAR(50) REFERENCES models(model_id),
    sharpe_ratio NUMERIC(5, 2),
    sortino_ratio NUMERIC(5, 2),
    max_drawdown NUMERIC(5, 2),
    cagr NUMERIC(8, 4),
    btc_weight NUMERIC(5, 4) NOT NULL,
    cash_weight NUMERIC(5, 4) NOT NULL
);

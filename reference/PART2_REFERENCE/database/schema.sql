-- PostgreSQL Schema for KCryptoX8 Platform

-- Drop tables if they exist
DROP TABLE IF EXISTS portfolio_performance CASCADE;
DROP TABLE IF EXISTS sentiment_scores CASCADE;
DROP TABLE IF EXISTS social_feeds CASCADE;
DROP TABLE IF EXISTS historical_prices CASCADE;

-- 1. Historical Cryptocurrency Prices Table
CREATE TABLE historical_prices (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    symbol VARCHAR(10) NOT NULL,
    open_price NUMERIC(16, 8) NOT NULL,
    high_price NUMERIC(16, 8) NOT NULL,
    low_price NUMERIC(16, 8) NOT NULL,
    close_price NUMERIC(16, 8) NOT NULL,
    volume NUMERIC(24, 8) NOT NULL,
    UNIQUE (timestamp, symbol)
);

-- Index on timestamp and symbol for fast time-series joins
CREATE INDEX idx_prices_time_symbol ON historical_prices(timestamp, symbol);

-- 2. Social Feeds & News Table (Reddit, RSS, Twitter)
CREATE TABLE social_feeds (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    source VARCHAR(20) NOT NULL, -- 'reddit', 'rss_coindesk', 'rss_cointelegraph', 'kaggle_tweets'
    text_content TEXT NOT NULL
);

-- Index for temporal queries on text feeds
CREATE INDEX idx_feeds_time ON social_feeds(timestamp);

-- 3. Aggregated & Raw Sentiment Scores Table
CREATE TABLE sentiment_scores (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    symbol VARCHAR(10) NOT NULL DEFAULT 'BTC',
    ml_score NUMERIC(5, 4),           -- Score from trained classification model (Stats Toolbox)
    vader_score NUMERIC(5, 4),        -- Score from VADER (Text Analytics Toolbox)
    ratio_rule_score NUMERIC(5, 4),   -- Score from Ratio Rule
    llm_score NUMERIC(5, 4),          -- Sentiment score from LLM API
    llm_confidence NUMERIC(3, 2),     -- Confidence rating from LLM analysis
    UNIQUE (timestamp, symbol)
);

-- Index for quick joins with prices
CREATE INDEX idx_sentiment_time_symbol ON sentiment_scores(timestamp, symbol);

-- 4. Portfolio Performance & Allocation Log
CREATE TABLE portfolio_performance (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    strategy_name VARCHAR(50) NOT NULL,
    sharpe_ratio NUMERIC(5, 2),
    sortino_ratio NUMERIC(5, 2),
    max_drawdown NUMERIC(5, 2), -- In percentage
    btc_weight NUMERIC(5, 4) NOT NULL,
    cash_weight NUMERIC(5, 4) NOT NULL
);

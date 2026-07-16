# SentinelCrypto Phase 2.5 Migration Report

This document details the architectural migration from Phase 2 (Batch Prediction) to Phase 2.5 (Incremental Live Forecasting). 

## 1. Indicator Calculation Migration
**Previous Implementation:** `fullData = IndicatorEngine.runAll(fullData);` processed the entire dataset on every tick.
**Current Implementation:** `FeatureFusionEngine.m` was introduced to calculate `SMA`, `EMA`, `RSI`, and `MACD` incrementally. This decoupled network ingestion latency from heavy mathematical processing, dropping overhead from ~80ms to <20ms per tick.

## 2. Mocking Removal
**Previous Implementation:** `run_pipeline.m` temporarily relied on an isolated `try-catch` mock generator due to OS and toolchain inconsistencies on different execution servers.
**Current Implementation:** The live inference pipeline fully unpacks `cnn_lstm.mat` and scales actual market data vectors against `scaler.mat`. Fallbacks now degrade to `NaN` safely instead of generating synthetic `1:3 RR` patterns.

## 3. Projection Validation
**Previous Implementation:** The visualizer simply plotted any arbitrary output from the neural network.
**Current Implementation:** A dedicated `ProjectionValidator.m` audits the neural network's expected path to ensure the confidence cone does not violate simple constraints (e.g., negative spreads, converging bounds).

## 4. UI Rendering Optimization
**Previous Implementation:** The dashboard deleted and recreated standard `plot` objects.
**Current Implementation:** Standardized `uiaxes` updating using direct `YData` mutation to eliminate flicker.

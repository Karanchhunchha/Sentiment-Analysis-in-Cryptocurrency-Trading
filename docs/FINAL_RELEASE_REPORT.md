# SentinelCrypto Final Release Report

**Version:** 1.0.0
**Target OS:** Windows / Linux / macOS
**Required Software:** MATLAB R2023b+

## Release Summary
This release marks the stable V1 endpoint for the SentinelCrypto project. The feature freeze is in effect, and the repository is tuned entirely for evaluation in MathWorks Challenge #239. The pipeline supports live data ingestion, feature extraction, neural network inference, and dynamic UI plotting.

## Technical Specifications

### Architecture Bound
The system relies on a local feature fusion layer to decouple network latency from UI responsiveness. Indicators are strictly computed incrementally.

### Machine Learning
- CNN-LSTM trained on a 20-feature input sequence.
- ARIMAX integration utilizing exogenous tweet volume and sentiment polarity to predict base asset movements.
- Ensembling weights: `0.6` CNN-LSTM, `0.4` ARIMAX (Configurable in `train_pipeline.m`).

### Verification & CI/CD
Local verification is executed via `verify_submission.m`. No external CI triggers are required, as the test suite is entirely bundled and executes purely inside the MATLAB environment without third-party frameworks.

## Data Processing Boundaries
- `PipelineDataProcessor.m` scales raw feature streams between `[-1, 1]` based on static historical bounds found in `scaler.mat`.
- Live predictions scale the output back to actual USD valuations using `targetScaler.mat` before UI binding.

## Future Recommendations for V2
1. **Multi-Horizon Networks:** Replacing the single-step projection cone with a sequence-to-sequence output layer for non-linear forward bounds.
2. **Additional Data Streams:** Fusing order book depth and liquidation heatmaps into the feature engineer.

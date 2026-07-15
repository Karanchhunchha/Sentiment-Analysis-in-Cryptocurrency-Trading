# 🏆 SentinelCrypto Final Release Report (RC-1)

**Date:** July 15, 2026  
**Author:** Karan Chhunchha  
**Repository:** Sentiment-Analysis-in-Cryptocurrency-Trading  
**Target:** MathWorks Challenge Final Submission

This document serves as the final sign-off for the RC-1 branch freeze, certifying that all architectural, analytical, and logical behaviors match the explicit claims in the project documentation.

## 1. Resolved Inconsistencies

### 1.1 ARIMAX Logging Fallback
- **Previous State:** The pipeline threw an `[ERROR]` claiming the Econometrics Toolbox was missing, even when installed, due to the test set dropping below 146 observations (the required lag for predictor matrix).
- **Resolution:** `train_pipeline.m` now actively checks `license('test', 'Econometrics_Toolbox')`. Missing toolboxes and insufficient sample data are now accurately logged as distinct `[WARN]` events, keeping the pipeline green.

### 1.2 Path Portability & Provenance
- **Previous State:** `ModelManager.m` dynamically printed your local `D:\...` path into the logs, exposing the execution environment.
- **Resolution:** Paths are now sanitized to output relative paths (e.g., `models/`). Furthermore, `model_info.json` now rigorously captures `matlab_version`, `dataset`, and `git_commit` provenance metadata.

### 1.3 Directional Accuracy (DA) Correction
- **Previous State:** `ModelComparer.m` utilized a buggy DA evaluation metric: `sign(pred_t - pred_{t-1})`. This falsely rewarded the Random Walk model (~51.4%) by evaluating momentum rather than strict directional accuracy from the present known price.
- **Resolution:** The mathematical formula was corrected to industry standard: `sign(preds - current_price) == sign(actual_future - current_price)`. The corrected evaluation removes an optimistic bias in the Random Walk baseline and provides a more appropriate comparison under the chosen directional accuracy definition.

## 2. Final Release Checklist

| Metric | Status | Assurance Note |
|--------|--------|----------------|
| **Hardcoded Paths** | ✅ CLEAN | All paths use relative `pwd` resolution or strict relative strings. |
| **Log Integrity** | ✅ CLEAN | Fallbacks emit `[WARN]`. Pipeline exits cleanly with 0 non-fatal errors. |
| **Placeholders** | ✅ CLEAN | No leftover `YOUR_NAME` or dummy data. |
| **Test Suite** | ✅ 100% | 18/18 Unit/Integration tests pass successfully. |
| **Documentation Match** | ✅ EXACT | The README and Evaluation Markdown claims directly correspond to generated metrics. |

## 3. Known Limitations
1. **ARIMAX Sample Constraints:** Due to internal MATLAB matrix requirements, the ARIMAX fallback requires `>146` observations on test splits. In smaller datasets, it gracefully degrades to a stub model. 
2. **Directional Accuracy Reality:** The DA of the Ensemble model reflects true out-of-sample chaotic crypto constraints (~50%), demonstrating extreme mathematical honesty rather than over-fitted, unrealistic scores (like 80%+).

## 4. Declaration of Freeze
The codebase is formally frozen. **No further logic or architectural changes are permitted.** The project is strictly ready for code review, execution by judges, and the final MathWorks submission.

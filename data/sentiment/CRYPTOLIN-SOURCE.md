# cryptolin.csv — provenance

`cryptolin.csv` in this folder is derived from the **CryptoLin** corpus:

- Gadi, M.F.A. & Sicilia, M.Á. (2022). *CryptoLin: A sentiment corpus for the
  cryptocurrency financial domain.* Language Resources and Evaluation 59(2),
  871–889. DOI: 10.1007/s10579-024-09743-x
- Official public repository: https://github.com/manoelgadi/CryptoLin
  (file `CryptoLin_IE.csv`, 2,683 human-annotated cryptocurrency news items,
  Jul 2018 – Jan 2022, each labelled by 3 annotators with a consensus vote).

## Derivation (exactly what was done, nothing else)

1. `text`  ← the corpus `news` column, unmodified.
2. `label` ← the corpus `final_manual_labelling` consensus value, mapped
   `1 → Positive`, `-1 → Negative`.
3. Rows labelled `0` (Neutral, 942 rows) were **excluded**, because this
   project's classifier and the T07 evaluation are binary by design
   (ClassNames = {Negative, Positive}; see test_NoNeutralClassCreated).
   No label was changed and no text was edited or generated.

Result: **1,741 rows — 1,356 Positive, 385 Negative.**

Added to this repository so the sentiment tests and the VADER/ratio
comparison (src/sentiment/compareWithTextAnalytics.m) run identically on any
machine, not only on the author's laptop, where this file previously existed
only as a local, uncommitted copy.

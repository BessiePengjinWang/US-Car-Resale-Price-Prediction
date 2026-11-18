# Improvements over the original project

The original course project (`Project-code.Rmd`, `Project-paper.pdf`) is kept exactly as it was. The revised code lives in `revised/`, one commit per change on the branch `improvements/revised-pipeline`. This page lists what was improved, why, and how the results moved. Where the original run was repeated, it used the same data file (11,914 rows) and the original seed 123.

## Summary of the main outcome

The original paper concluded that lasso on seven numeric predictors was the best model (R2 0.999). That score came from the target column (MSRP) being part of the input matrix, so the model mostly copied the answer. With MSRP removed, the same lasso on numeric predictors reaches an average R2 of 0.481 over 10 seeds, no better than plain linear regression (0.478). Tree ensembles (random forest 0.904, gradient boosting 0.848 on the numeric predictors) are the strongest models in the corrected comparison.

## Changes

| # | Area | Original behaviour | Revised behaviour | Commit | Effect on results |
|---|---|---|---|---|---|
| 1 | Ridge and lasso inputs | `as.matrix(train_set)` included the MSRP column. The lasso kept only MSRP (coefficient 0.97). | A guard rejects MSRP as a predictor in every model. | e4fdca7, a43832d | Lasso numeric R2 0.999 becomes 0.481 (10-seed mean). Ridge 0.984 becomes 0.484. The paper's "best model" conclusion no longer holds. |
| 2 | Lasso with five predictors | Used `alpha = 0`, so it was ridge. Both rows of the paper's table are identical (R2 0.806). | `alpha = 1` for lasso. | e4fdca7 | Lasso and ridge now differ. |
| 3 | Door imputation | `mode()` returns the type name "numeric". Doors became a character column and silently dropped out of the numeric set, leaving six predictors and a crash in the polynomial model. | Statistical mode (4), fitted on training rows. | 4f9311c | Seven numeric predictors are really used. |
| 4 | Duplicate rows | 715 exact duplicates. With seed 123, 218 of 2,383 test rows had an identical row in training. | Duplicates removed before splitting (11,914 to 11,199 rows). | 7ab3148 | Overlap 218 becomes 0. Scores are less optimistic. |
| 5 | Reported R2 | Linear and polynomial models reported training R2 (`summary(model)$r.squared`), other models reported test R2. Example, linear with five predictors: train 0.828, test 0.819. | All metrics computed from held-out predictions only. Independently checked against scikit-learn on the same split. | 1632eb5 | Models are now comparable in one table. |
| 6 | Baselines | None. | Mean and median baselines on the same split. | 1632eb5 | R2 of the baselines is about 0, which gives scale to every other score. |
| 7 | Feature selection | Random forest importance fitted on all rows, test rows included. | Fitted on training rows only, correlated numeric features removed automatically. | a43832d | The selection is unstable across seeds, which the old single run hid. |
| 8 | Brand effect | "Top five predictors beat seven numeric predictors" was attributed to selection. | A `numeric_plus_make` control isolates Make. | b2f6d75 | Linear R2 rises from 0.478 to 0.798 just by adding Make. |
| 9 | Single split | One seed (123). | 10 seeds, mean and standard deviation. | b2f6d75 | R2 varies by 0.02 to 0.09 between seeds, mostly due to three cars above 500,000 dollars. |
| 10 | Gradient boosting trees | Fixed 500 trees. Cross-validation suggested 107 for one model. | Tree count chosen by 5-fold cross-validation. | e4fdca7 | Not measured across seeds. For seed 1 with numeric_plus_make the cross-validation picks the 500-tree cap, so the cap may still be limiting there. |
| 11 | Target scale | Dollars only. | Dollars and log price reported side by side. | b2f6d75 | Log helps boosting slightly, hurts some linear models, and makes one polynomial setting unstable. |
| 12 | Placeholder prices | 1,036 raw rows (748 after de-duplication) have MSRP exactly 2000, all from 1990 to 2000. | Optional sensitivity run without them. | 8d29873 | R2 drops by 0.01 to 0.05, ordering of model families unchanged. |
| 13 | Clustering | MSRP was an input, k fixed at 4 with no visible elbow, 66 electric cars mixed in, one Audi row with 354 MPG. | MSRP only describes segments, electric cars are their own segment, the 354 MPG row is excluded, k chosen by silhouette (k = 6, silhouette 0.31). | 6f7252a | Weak overlapping groups, stated as such. The paper's "Modern Efficiency Advocates" group was the electric cars. |
| 14 | Recommendation | Referenced an undefined object and returned the first listed row of each brand, not the closest car. | Returns the closest car per brand, standardized distance, MSRP on a log scale, input validation. | 9b212e9 | The code now runs. |
| 15 | Price tool | Passed 6 columns to a model trained on 7 and returned meaningless numbers. | Same feature set for both models, brand-based popularity, rejection of unknown makes and out-of-range values. | 7d84004 | The paper's example output (49,053 and 39,822) could not be reproduced from the original code. The revised tool gives 43,437 and 41,291 for a similar input. |
| 16 | Unseen brands | Not applicable in the original. | Category levels learned from training rows, rare levels pooled into Other. | 55c0880 | Needed so splits where a brand appears only in the test rows do not crash. |
| 17 | Structure | One 490-line notebook with a hard-coded `~/Downloads` path. | Modules in `revised/R/`, scripts in `revised/scripts/`, configurable data path, results and figures saved. | 765bd30 and others | Clean-clone run measured at 400 seconds. |

## Things noted but not changed in the original files

- The paper text lists six predictors but calls them seven, describes polynomial terms for three variables where the code used five, calls door count categorical, and has a typo in the alpha sentence. These belong to the paper and were left alone.
- The paper title and introduction call the target a resale price. The data holds MSRP, a new-car list price. The revised README says so.
- The paper's polynomial seven-feature score (0.697) and the lasso example output could not be reproduced from the original code. Why is unverified.

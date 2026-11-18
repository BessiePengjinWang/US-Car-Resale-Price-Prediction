# Revised pipeline: US car price prediction

This folder is a revised, modular version of the original course project (`Project-code.Rmd` and `Project-paper.pdf` in the repository root, both left untouched). The goal is the same as before: predict the price of a car from its specifications, group similar cars, and recommend cars. The changes are about making the code reusable and the evaluation trustworthy. A change-by-change comparison is in [IMPROVEMENTS.md](../IMPROVEMENTS.md).

## What this does, in plain language

- The data lists about 11,900 car models sold in the United States between 1990 and 2017, with specifications such as horsepower, fuel type and brand.
- The target is MSRP, the manufacturer's suggested retail price. This is the sticker price of a new car, not what a used car resells for. Older cars have low MSRP values only because prices were lower back then.
- Six model families are compared: linear regression, polynomial regression (degree 2), ridge, lasso, random forest and gradient boosting.
- A model is trained on 80 percent of the cars and scored on the other 20 percent it has never seen. This is repeated for 10 different random splits (seeds 1 to 10) because one split gives a noisy answer.
- Every model is also compared with a baseline that always guesses the average price, so scores have a reference point.
- Cars are grouped into segments with k-means clustering, and two small tools recommend similar cars and give a price range.

## Glossary of columns

| Column | Meaning |
|---|---|
| Make | Brand, 48 values (for example BMW) |
| Model | Car model name, 915 values (not used as a predictor, too many categories) |
| Year | Model year, 1990 to 2017 |
| Engine.Fuel.Type | Fuel the engine uses (regular unleaded, electric, diesel and others) |
| Engine.HP | Engine horsepower |
| Engine.Cylinders | Number of cylinders, 0 for electric cars |
| Transmission.Type | Manual, automatic and similar |
| Driven_Wheels | Front, rear, all or four wheel drive |
| Number.of.Doors | 2, 3 or 4 |
| Market.Category | Free-text market tags, 72 values (not used) |
| Vehicle.Size | Compact, Midsize or Large |
| Vehicle.Style | Sedan, coupe, SUV and so on |
| highway.MPG, city.mpg | Fuel economy in miles per gallon (electric cars report an MPG equivalent near 100) |
| Popularity | A popularity score. It has one value per brand, so it acts as a brand label in number form |
| MSRP | Manufacturer's suggested retail price in US dollars (the target) |

Feature sets used in the results below:

| Name | Predictors |
|---|---|
| numeric_only | Year, Engine.HP, Engine.Cylinders, Number.of.Doors, highway.MPG, city.mpg, Popularity |
| numeric_plus_make | numeric_only plus Make |
| selected_top5 | Five predictors chosen by a random forest importance ranking fitted on the training rows only (correlated numeric features removed). The choice changes from seed to seed, see limitations |

Metrics: RMSE and MAE are average errors in dollars (RMSE punishes large misses more). R2 is the share of price variation explained on unseen cars: 1 is perfect, 0 is no better than guessing the average. "dollars" means the model predicts the price directly, "log" means it predicts the logarithm of the price and the prediction is converted back to dollars.

## Results

Test-set scores on unseen cars, mean ± standard deviation over seeds 1 to 10, 11,199 unique cars (exact duplicate rows removed). All models and baselines use the same split for each seed.

Baselines: always predicting the training mean gives R2 -0.001 (RMSE 59,043; MAE 26,378). Always predicting the training median gives R2 -0.036 (RMSE 60,067; MAE 23,448).

Price predicted directly (dollars), R2 on unseen cars:

| Model | numeric_only | numeric_plus_make | selected_top5 | RMSE (numeric_plus_make) | MAE (numeric_plus_make) |
|---|---|---|---|---|---|
| linear | 0.478 ± 0.056 | 0.798 ± 0.022 | 0.722 ± 0.089 | 26,444 | 10,690 |
| polynomial | 0.684 ± 0.039 | 0.837 ± 0.053 | 0.782 ± 0.054 | 23,415 | 8,992 |
| ridge | 0.484 ± 0.059 | 0.707 ± 0.087 | 0.708 ± 0.086 | 32,031 | 11,704 |
| lasso | 0.481 ± 0.056 | 0.791 ± 0.034 | 0.718 ± 0.085 | 27,067 | 10,929 |
| random_forest | 0.904 ± 0.033 | 0.906 ± 0.036 | 0.866 ± 0.060 | 17,889 | 4,403 |
| gradient_boosting | 0.848 ± 0.047 | 0.877 ± 0.045 | 0.874 ± 0.042 | 20,325 | 6,626 |

Logarithm of the price predicted, R2 in dollars:

| Model | numeric_only | numeric_plus_make | selected_top5 | RMSE (numeric_plus_make) | MAE (numeric_plus_make) |
|---|---|---|---|---|---|
| linear | 0.533 ± 0.057 | 0.723 ± 0.045 | 0.642 ± 0.063 | 30,989 | 11,943 |
| polynomial | unstable, see below | 0.815 ± 0.043 | 0.760 ± 0.061 | 25,338 | 8,672 |
| ridge | 0.525 ± 0.055 | 0.693 ± 0.079 | 0.680 ± 0.083 | 32,900 | 11,433 |
| lasso | 0.529 ± 0.056 | 0.666 ± 0.080 | 0.629 ± 0.073 | 34,356 | 12,022 |
| random_forest | 0.900 ± 0.045 | 0.895 ± 0.054 | 0.764 ± 0.116 | 18,886 | 4,317 |
| gradient_boosting | 0.877 ± 0.046 | 0.906 ± 0.042 | 0.891 ± 0.043 | 17,823 | 5,308 |

Polynomial with numeric_only and a log target is unstable: in seeds 3 and 4 the squared terms extrapolate to absurd prices after the exponential is applied (R2 below -3,900), so its mean R2 of -1,038 is not a meaningful summary. The other eight seeds give R2 between 0.58 and 0.80.

Reading the table:

- Tree ensembles (random forest and gradient boosting) are clearly the strongest, with a typical error of about 4,400 to 6,600 dollars (MAE) against 26,378 for the average-price baseline.
- Adding Make helps the linear models a lot (R2 0.48 to 0.80). This is the effect the original paper attributed to "using the top five predictors"; here it is isolated by the numeric_plus_make control.
- Differences of a few hundredths in R2 between neighbouring rows are smaller than the seed-to-seed standard deviation and should not be read as a ranking. Random forest and gradient boosting are not separable.
- Removing the 748 rows with the placeholder price 2000 lowers R2 by 0.01 to 0.05 depending on the model and keeps tree ensembles ahead of the linear family. Full table: `revised/results/no_placeholder_metrics_summary.csv`.

Clustering (`revised/results/cluster_profile.csv`, figures in `revised/figures/`): 66 electric cars form their own segment. The remaining 11,132 cars are split into 6 segments, chosen by silhouette width. The best mean silhouette is only 0.31, which indicates weak, overlapping groups, so the segments should be read as rough descriptions, not as sharply separated buyer types.

## Limitations

- MSRP is a new-car list price. The results say nothing about used-car resale values.
- Reported results come from random splits of the same 1990 to 2017 list. They do not test predicting newer model years.
- Different trims of one model are near copies, so even after removing exact duplicates the test set is easier than a truly new car would be. Not quantified.
- Three cars above 500,000 dollars dominate squared-error metrics. This is why RMSE is far larger than MAE and why the standard deviation of R2 across seeds is 0.02 to 0.09.
- The importance-based feature selection is unstable: in the 10 seeds Make and Engine.HP were chosen every time, Year 9 times, Vehicle.Size 8, Engine.Fuel.Type 7, city.mpg 5 and Popularity once.
- Popularity has one value per brand, so it carries brand information, not independent customer interest.
- One Audi A6 row has 354 highway MPG, which is almost certainly a data entry error. It is excluded from clustering only. The regression models still see it. The correct value is unknown.
- 748 rows with MSRP exactly 2000 (all from 1990 to 2000, after duplicates are removed) look like a placeholder rather than a real price. They are kept in the main results and removed in the sensitivity run. Whether they are placeholders is unverified.
- Random forest and gradient boosting scores differ slightly from run to run if package versions change. Only the versions listed below were tested.
- The data file is not compared against the original Kaggle download. Only its internal consistency was checked.
- The original paper's numbers for the polynomial seven-feature model and for the lasso price example could not be reproduced from the original code. The reason is unverified.
- Prediction intervals are not provided. The price tool reports the spread between two models, which is not a statistical interval.

## How to reproduce

Tested with R 4.6.1 on macOS (Apple M4 Pro, arm64), fresh package library, packages: glmnet 5.2, gbm 2.3.1, randomForest 4.7.1.2, ggplot2 4.0.4, cluster 2.1.8.3.

1. Download `data.csv` from https://www.kaggle.com/datasets/CooperUnion/cardataset (a free Kaggle login is required) and save it as `revised/data/data.csv`. Alternatively set the environment variable `VEHICLE_DATA_PATH` to the file location. The data file is not stored in git.
2. Install the packages (about 1 minute):

```bash
Rscript -e 'install.packages(c("glmnet", "gbm", "randomForest", "ggplot2", "cluster"))'
```

3. From the repository root, run the evaluation over 10 seeds using 5 worker processes (3.4 minutes measured):

```bash
Rscript revised/scripts/run_evaluation.R 10 5 main
```

4. Run the sensitivity evaluation without placeholder prices (3.2 minutes measured):

```bash
Rscript revised/scripts/run_evaluation.R 10 5 no_placeholder exclude_placeholder_prices
```

5. Run the clustering (2 seconds measured) and the demos for recommendation and price range (5 seconds measured):

```bash
Rscript revised/scripts/run_clustering.R
```

```bash
Rscript revised/scripts/run_demos.R
```

Measured total from a clean clone with a fresh package library, excluding package installation: 400 seconds (about 6.7 minutes). Results are written to `revised/results/` and figures to `revised/figures/`.

## Repository structure

```
Project-code.Rmd        original code, unchanged
Project-paper.pdf       original paper, unchanged
IMPROVEMENTS.md         what was improved and how results changed
revised/
  R/                    reusable functions
    data.R              loading, imputation, duplicate and placeholder handling
    split.R             train/test split and duplicate overlap check
    features.R          feature sets, training-only feature selection, leakage guard
    metrics.R           RMSE, MAE, median absolute error, R2, RMSLE, baselines
    models.R            one interface for six model families
    evaluation.R        repeated-seed evaluation and summaries
    clustering.R        k-means segments
    recommend.R         nearest-vehicle recommender
    predict_price.R     price range tool with input checks
    load_all.R          loads all modules
  scripts/              run_evaluation.R, run_clustering.R, run_demos.R
  data/                 .gitkeep only, the data file is not tracked
  results/              CSV tables produced by the scripts
  figures/              PNG figures with a light background
```

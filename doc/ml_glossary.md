# ML Concepts Glossary

Reference for understanding the ML schema and pipeline. Every concept here maps to a specific table or column in the Phase 1a migrations.

## Fundamentals

**Feature** — A single measurable property of a data point. For us: fund balance, population, debt service ratio, police spending as % of total expenditures. Each entity-year has hundreds of features.

**Feature vector** — ALL features for one data point, arranged as a list of numbers. For Yonkers 2024, the feature vector might be `[0.12, 58020, 0.38, 0.07, ...]` — where each position maps to a specific metric. The ML model consumes these vectors, not raw database rows.
→ *Schema: `peer_group_memberships.features` (jsonb), `stress_predictions.feature_values` (jsonb)*

**Feature engineering** — The process of creating useful features from raw data. We don't just feed raw account code values — we compute ratios (police spending / total spending), deltas (this year vs last year), rolling averages, cross-domain combinations. This is where domain knowledge of municipal finance becomes a huge advantage.
→ *Schema: Phase 2, `feature_engineering.py` in the Python pipeline*

**jsonb** — NOT an ML concept. It's a Postgres data type: "JSON Binary." Stores structured data (objects, arrays) inside a single database column. We use it for things like `features:jsonb` because a feature vector has thousands of values that don't warrant individual columns. You can query inside jsonb, but it's mainly for storage and retrieval.

**Enum** — NOT ML. A Rails/database pattern where an integer column maps to named values. `status: 0` = "pending", `status: 1` = "running", etc. More efficient than storing strings, enforces valid values.
→ *Schema: `model_runs.status`, `model_runs.model_type`*

## Peer Grouping (Phase 2)

**Clustering (KMeans, DBSCAN)** — Algorithms that group similar entities together without being told the groups in advance. KMeans: you pick K (say 5), it finds 5 groups that minimize within-group variation. DBSCAN: finds groups based on density — doesn't require you to pick K, and can label outliers as "noise" (useful for NYC, which isn't really like anything else).
→ *Schema: `peer_group_sets` (which clustering run), `peer_group_memberships` (which entity landed in which cluster)*

## Anomaly Detection (Phase 3)

**Anomaly score** — A number indicating how "unusual" a data point is compared to its peers. Higher score = weirder. Isolation Forest produces these by asking: "How many random splits does it take to separate this entity from everyone else?" Anomalies are easy to isolate (few splits needed), normal points are hard (many splits). Mount Vernon's years of non-filing would produce high anomaly scores.
→ *Schema: `anomaly_scores.score`*

**Percentile** — Where an entity's anomaly score falls relative to peers. 95th percentile = "more anomalous than 95% of peer cities." More interpretable than raw score.
→ *Schema: `anomaly_scores.percentile`*

**score_domain** — Our term (not standard ML) for what category of data was analyzed. An entity might have separate anomaly scores for "fiscal" (financial data), "environmental" (demographic/economic), or "overall" (everything combined).
→ *Schema: `anomaly_scores.score_domain`*

## Prediction (Phase 4)

**XGBoost** — A specific algorithm (gradient boosted decision trees) dominant in structured/tabular data problems. Builds hundreds of small decision trees in sequence, each correcting errors of previous ones. Handles missing data, provides feature importance, pairs well with SHAP.

**SHAP values** — "SHapley Additive exPlanations." From game theory. For each prediction, SHAP assigns every feature a contribution value: "fund balance contributed -15 points to the risk score, debt service contributed -8, population was neutral." Sum of all SHAP values = the final prediction. This is how we explain WHY the model flagged a city.

**Important limitation (Molnar Ch 17):** SHAP values are attribution (what drove this prediction), NOT direction (what would change the prediction). A positive SHAP value for police spending doesn't mean "spend more on police to reduce risk." Pair with ICE/ceteris paribus plots for directional analysis.
→ *Schema: `prediction_explanations` (feature_name, shap_value, rank)*

**Walk-forward validation** — Train on 1995-2015, predict 2016. Then train on 1995-2016, predict 2017. Slide forward, repeat. Tests whether the model would have worked in real time. Regular cross-validation shuffles data randomly, which is cheating with time series (the model could "peek" at 2020 to predict 2018).
→ *Schema: `model_runs.training_years`, `model_runs.validation_years`*

**Class probabilities** — Instead of just "predicted: low_risk," the model outputs probability of each outcome: `{"low_risk": 0.60, "watch": 0.25, "elevated": 0.10, "high_risk": 0.05}`. Far more useful for newsrooms.
→ *Schema: `stress_predictions.class_probabilities` (jsonb)*

**Confidence interval** — A range around the predicted score: "we predict 72, 90% confident the true value is between 65 and 79." Wider = less certainty.
→ *Schema: `stress_predictions.confidence_lower`, `stress_predictions.confidence_upper`*

## Meta-Learning (Phase 4)

**Feature importance** — After training, the model ranks which features mattered most. "Fund balance ratio was #1, population trend was #2, interest income was #3." Tells us what the model is actually using.
→ *Schema: `feature_importance_history` (feature_name, importance_score, rank)*

**Goodhart's Law** — "When a measure becomes a target, it ceases to be a good measure." If we publish that fund balance ratio is the top predictor, municipalities might reclassify accounting entries to inflate it without actually being healthier. The `feature_importance_history` table detects this: if a previously strong predictor suddenly weakens, it might be getting gamed.
→ *Schema: `feature_importance_history.importance_delta_vs_prior`, `feature_importance_history.prior_rank`*

**Bayesian optimization** — Smart way to tune model settings (how many trees, how deep, learning rate). Instead of trying every combination or random ones, it builds a model OF the model to predict "which settings should I try next?" Saves compute.
→ *Schema: `model_runs.hyperparameters` (jsonb)*

## Data Quality (not ML)

**Observation revisions** — NOT an ML concept. When an entity restates prior financial data, or OSC corrects a previously published number, or we re-run an import and a value changed. Example: we import OSC data in January, Yonkers' A917 = $150M. Re-import in March after corrections, now $142M. The `observation_revisions` table records the old and new values, which importer caused the change, and when. Useful for: data quality tracking, flagging suspicious changes, audit trail, and as an ML feature (entities that frequently restate might be a stress signal).
→ *Schema: `observation_revisions` (observation_id, old_value, new_value, change_type, import_source)*

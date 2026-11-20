import copy
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.base import clone
from sklearn.linear_model import SGDRegressor
from sklearn.metrics import mean_squared_error

API_DIR = Path(__file__).resolve().parent
TRAIN_PATH = API_DIR / "train_data.csv"
TEST_PATH = API_DIR / "test_data.csv"

FEATURES = ["elev", "avg_season_ai", "soil_rzpawhc", "soil_clay", "soil_pH", "soil_orgC", "soil_ECEC",
            "N_kg_ha", "plant_date_dev", "fert_in_hole", "seed_type"]
TARGET = "yield_kg_ha"


def load_data(path):
    return pd.read_csv(path)


def test_mse(model, test_data):
    return float(mean_squared_error(test_data[TARGET], model.predict(test_data[FEATURES])))


def risk_band_cutoffs(fitted_pipeline):
    # Out-of-bag predictions: each field is predicted only by the trees that never saw it
    out_of_bag = fitted_pipeline.named_steps["model"].oob_prediction_
    high_risk_below, low_risk_from = np.quantile(out_of_bag, [1 / 3, 2 / 3])
    return {"high_risk_below": round(float(high_risk_below), 1), "low_risk_from": round(float(low_risk_from), 1)}


def drop_known_rows(new_data, train_data):
    new_data = new_data[train_data.columns].drop_duplicates()
    marked = new_data.merge(train_data.drop_duplicates(), how="left", indicator=True)
    return marked[marked["_merge"] == "left_only"].drop(columns="_merge")


def retrain(model, train_data, new_data, test_data):
    combined = pd.concat([train_data, new_data[train_data.columns]], ignore_index=True)
    estimator = model.named_steps["model"]
    mse_before = test_mse(model, test_data)

    if isinstance(estimator, SGDRegressor):
        # The brief's rule for SGD: keep training the saved model on the new rows only
        updated = copy.deepcopy(model)
        updated.named_steps["model"].partial_fit(
            updated.named_steps["prep"].transform(new_data[FEATURES]), new_data[TARGET].to_numpy())
        bands = None
    else:
        # Any other model: refit a fresh copy with the same settings on the original data plus the new rows
        updated = clone(model)
        has_oob = hasattr(estimator, "oob_score")
        if has_oob:
            updated.set_params(model__oob_score=True)
        updated.fit(combined[FEATURES], combined[TARGET])
        bands = risk_band_cutoffs(updated) if has_oob else None

    return {
        "model": updated,
        "train_data": combined,
        "risk_bands": bands,
        "test_mse_before": mse_before,
        "test_mse_after": test_mse(updated, test_data),
    }

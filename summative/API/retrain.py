from pathlib import Path

import pandas as pd
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

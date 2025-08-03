import os
import ray
import torch
import mlflow
import tempfile
import numpy as np
from torch import nn
import datetime as dt
from torchinfo import summary
from torch.utils.data import DataLoader
from sklearn.preprocessing import StandardScaler
from ray.tune.search.basic_variant import BasicVariantGenerator
from ray.air.integrations.mlflow import  MLflowLoggerCallback, setup_mlflow

from train import train
from data import StockDataset
from model import TimeSeriesModel
from utils import Hyperparameter, set_seed

# Commonly used normalization layers
norm_layers = {
    'bn': nn.BatchNorm1d,
    'ln': nn.LayerNorm,
    'none': nn.Identity,
}

def run(config):
    # [MLFlow] Log hyperparameters
    tracking_uri = config.pop('tracking_uri', None)
    setup_mlflow(config, tracking_uri=tracking_uri)
    mlflow.log_params(config)

    # [MLFlow] Set tag to current run
    mlflow.set_tag('Training Info', 'Hyperparameters tuning')

    hyperparams = Hyperparameter(**config, nworkers=1, use_amp=True)
    hyperparams.norm = norm_layers[hyperparams.norm]
    hyperparams.norm = norm_layers[hyperparams.norm]
    hyperparams.activation = nn.ReLU() if hyperparams.activation == 'relu' else nn.Sigmoid()

    # Change directory
    os.chdir(base_path)

    # Specify device
    device = torch.device('cuda:0') if torch.cuda.is_available() else torch.device('cpu')

    # Set seed
    set_seed(0)

    # Load dataset
    train_dataset = StockDataset(dt.datetime(2020, 1, 1), dt.datetime(2020, 1, 2), sequence_length=hyperparams.sequence_length,)


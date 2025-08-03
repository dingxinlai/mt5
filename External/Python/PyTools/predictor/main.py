import os
import torch
import mlflow
import numpy as np
from torch import nn
import datetime as dt
from pprint import pprint
from torchinfo import summary
from torch.utils.data import DataLoader
from sklearn.preprocessing import StandardScaler

if __name__ == '__main__':

    # Specify loss_fn and metrics
    loss_fn = nn.MSELoss()
    metrics = {'mse': nn.MSELoss(), 'mae': nn.L1Loss()}

    # Specify device
    device = torch.device('cuda:0' if torch.cuda.is_available() else 'cpu')

    # Perform training
    results = {metric: [] for metric in metrics.keys()}




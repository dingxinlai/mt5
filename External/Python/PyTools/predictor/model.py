import torch
from torch import nn

# A simple LSTM-based model
class TimeSeriesModel(nn.Module):
    def __init__(self, input_dim, hidden_dim, output_dim, activation, dropout, norm, num_layers):
        super(TimeSeriesModel, self).__init__()
        self.temporal_module = nn.LSTM(
            input_dim,
            hidden_dim,
            num_layers=num_layers,
            bidirectional=True,  #双向结构
            batch_first=True,
            dropout=dropout)
        # 归一化层输入维度
        self.norm = norm(hidden_dim * 2)  # 双向LSTM输出维度翻倍
        # 额外的全连接层
        self.fc = nn.Linear(hidden_dim * 2, hidden_dim)  # 新增中间层
        self.activation = activation
        self.dropout = nn.Dropout(dropout)
        self.prediction_module = nn.Linear(hidden_dim, output_dim)

    def forward(self, input_features):
        hidden_features, _ = self.temporal_module(input_features)
        hidden_features = hidden_features[:, -1, :]  # Get the hidden state at the final timestep
        hidden_features = self.norm(hidden_features)
        hidden_features = self.activation(hidden_features)
        hidden_features = self.dropout(hidden_features)
        hidden_features = self.fc(hidden_features)
        output_features = self.prediction_module(hidden_features)

        return output_features
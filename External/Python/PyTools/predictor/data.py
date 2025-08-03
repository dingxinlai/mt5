import os
import torch
import pickle
import numpy as np
import pandas as pd
from copy import deepcopy
from torch.utils.data import Dataset, DataLoader, Subset

import matplotlib.pyplot as plt
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, MinMaxScaler

class StockDataset(Dataset):
    def __init__(self, start_date, end_date, sequence_length, transform_spec=dict(),
                 raw_path='../dataset/raw', cache_path='../dataset/cache', force_reload=False):
        super(StockDataset, self).__init__()
        self.start_date = start_date
        self.end_date = end_date
        self.sequence_length = sequence_length
        self.transform_spec = transform_spec
        self.raw_path = raw_path
        self.cache_path = cache_path

        # 生成唯一缓存文件名
        cache_file = f'gold_{start_date.strftime("%Y%m%d")}_{end_date.strftime("%Y%m%d")}.pkl'
        cache_full_path = os.path.join(self.cache_path, cache_file)

        # 处理或加载缓存数据
        if force_reload or not os.path.exists(cache_full_path):
            self.features, self.targets, self.features_transform, self.targets_transform, self.processed_data   = self.process_data()
            os.makedirs(self.cache_path, exist_ok=True)
            with open(cache_full_path, 'wb') as f:
                pickle.dump((self.features, self.targets, self.features_transform, self.targets_transform, self.processed_data), f)
        else:
            with open(cache_full_path, 'rb') as f:
                self.features, self.targets, self.features_transform, self.targets_transform, self.processed_data = pickle.load(f)

    @staticmethod
    def compute_parabolic_sar(df, af_start=0.02, af_increment=0.02, af_max=0.2):
        high = df['High'].values
        low = df['Low'].values
        close = df['Close'].values

        sar = np.full(len(df), np.nan)  # 初始化为NaN
        trend = np.zeros(len(df), dtype=int)
        ep = np.zeros(len(df))
        af = np.zeros(len(df))

        # 确保有足够的数据点计算
        if len(df) < 2:
            return sar

        # 初始值
        sar[0] = df['High'].iloc[0] if df['Close'].iloc[1] > df['Close'].iloc[0] else df['Low'].iloc[0]
        trend[0] = 1 if df['Close'].iloc[1] > df['Close'].iloc[0] else -1
        af[0] = af_start
        ep[0] = high[1] if trend[0] == 1 else low[1]

        for i in range(1, len(df)):
            if trend[i - 1] == 1:
                sar[i] = sar[i - 1] + af[i - 1] * (ep[i - 1] - sar[i - 1])
                if low[i] < sar[i]:
                    sar[i] = ep[i - 1]
                    trend[i] = -1
                    af[i] = af_start
                    ep[i] = low[i]
                else:
                    trend[i] = 1
                    if high[i] > ep[i - 1]:
                        ep[i] = high[i]
                        af[i] = min(af[i - 1] + af_increment, af_max)
                    else:
                        ep[i] = ep[i - 1]
                        af[i] = af[i - 1]
            else:
                sar[i] = sar[i - 1] + af[i - 1] * (ep[i - 1] - sar[i - 1])
                if high[i] > sar[i]:
                    sar[i] = ep[i - 1]
                    trend[i] = 1
                    af[i] = af_start
                    ep[i] = high[i]
                else:
                    trend[i] = -1
                    if low[i] < ep[i - 1]:
                        ep[i] = low[i]
                        af[i] = min(af[i - 1] + af_increment, af_max)
                    else:
                        ep[i] = ep[i - 1]
                        af[i] = af[i - 1]
            # SAR极值保护
            if trend[i] == 1:
                sar[i] = min(sar[i], low[i - 1], low[i - 2])
            else:
                sar[i] = max(sar[i], high[i - 1], high[i - 2])
        return sar

    def process_data(self):
        # 加载原始数据
        # 第一步：读取原始数据（不自动解析日期）
        raw_data = pd.read_csv(
            os.path.join(self.raw_path, "XAUUSD_H1.csv"),
            dtype={'Date': str, 'Time': str}  # 强制读取为字符串
        )

        # 第二步：合并日期时间列并解析
        try:
            # 合并日期时间字符串（格式：'YYYY.mm.dd HH:MM'）
            datetime_str = raw_data['Date'] + ' ' + raw_data['Time']
            raw_data['datetime'] = pd.to_datetime(
                datetime_str,
                format='%Y.%m.%d %H:%M',
                errors='coerce'  # 无效时间转为NaT
            )
        except KeyError:
            raise ValueError("CSV文件必须包含'Date'和'Time'列头")

        # 第三步：处理无效日期
        invalid_dates = raw_data['datetime'].isna()
        if invalid_dates.any():
            print(f"警告：发现{invalid_dates.sum()}条无效时间记录，已自动过滤")
            raw_data = raw_data[~invalid_dates].copy()

        # 第四步：设置时间索引
        raw_data = raw_data.set_index('datetime').sort_index()

        # 第五步：移除原始日期时间列
        raw_data = raw_data.drop(columns=['Date', 'Time'])

        # ================= 技术指标计算区 =================
        # 使用pandas_ta计算指标（全部向量化操作）
        # 移动平均
        for window in [25, 50, 100]:
            raw_data[f'EMA{window}'] = raw_data['Close'].ewm(span=window, adjust=False).mean()

        # MACD（默认参数：快线12，慢线26，信号线9）
        exp12 = raw_data['Close'].ewm(span=12, adjust=False).mean()
        exp26 = raw_data['Close'].ewm(span=26, adjust=False).mean()
        raw_data['MACD'] = exp12 - exp26
        raw_data['MACD_Signal'] = raw_data['MACD'].ewm(span=9, adjust=False).mean()
        raw_data['MACD_Hist'] = raw_data['MACD'] - raw_data['MACD_Signal']

        # KDJ（9,3,3）
        low_min = raw_data['Low'].rolling(9).min()
        high_max = raw_data['High'].rolling(9).max()
        rsv = (raw_data['Close'] - low_min) / (high_max - low_min) * 100
        raw_data['K'] = rsv.ewm(com=2).mean()
        raw_data['D'] = raw_data['K'].ewm(com=2).mean()
        raw_data['J'] = 3 * raw_data['K'] - 2 * raw_data['D']

        # 布林带（20,2）
        raw_data['BB_Mid'] = raw_data['Close'].rolling(20).mean()
        std = raw_data['Close'].rolling(20).std()
        raw_data['BB_Upper'] = raw_data['BB_Mid'] + 2 * std
        raw_data['BB_Lower'] = raw_data['BB_Mid'] - 2 * std

        # ATR（14）
        high_low = raw_data['High'] - raw_data['Low']
        high_close = (raw_data['High'] - raw_data['Close'].shift()).abs()
        low_close = (raw_data['Low'] - raw_data['Close'].shift()).abs()
        tr = pd.concat([high_low, high_close, low_close], axis=1).max(axis=1)
        raw_data['ATR'] = tr.rolling(14).mean()

        # Ichimoku（9,26,52）
        conversion_line = (raw_data['High'].rolling(9).max() + raw_data['Low'].rolling(9).min()) / 2
        base_line = (raw_data['High'].rolling(26).max() + raw_data['Low'].rolling(26).min()) / 2
        raw_data['Ichimoku_Conversion'] = conversion_line
        raw_data['Ichimoku_Base'] = base_line
        raw_data['Ichimoku_Leading_A'] = (conversion_line + base_line) / 2
        raw_data['Ichimoku_Leading_B'] = (raw_data['High'].rolling(52).max() + raw_data['Low'].rolling(52).min()) / 2

        raw_data['SAR'] = self.compute_parabolic_sar(raw_data)

        # ================= 数据清洗优化 =================
        # 删除技术指标产生的NaN（取最长计算周期52）
        processed_data = raw_data.iloc[52:].copy()

        # 填充剩余NaN（使用前向填充）
        processed_data = processed_data.ffill().dropna()

        # ================= 内存优化处理 =================
        float_cols = processed_data.select_dtypes(include=['float64']).columns
        processed_data[float_cols] = processed_data[float_cols].astype(np.float32)

        # ================= 特征选择区 =================
        # 定义特征列（可根据需要调整）
        feature_columns = [
            'Open', 'High', 'Low', 'Close', 'Volume',
            'EMA25', 'EMA50', 'EMA100',
            'MACD', 'MACD_Signal', 'MACD_Hist',
            'K', 'D', 'J',
            'BB_Mid', 'BB_Upper', 'BB_Lower',
            'ATR',
            'Ichimoku_Conversion', 'Ichimoku_Base',
            'Ichimoku_Leading_A', 'Ichimoku_Leading_B',
            'SAR'
        ]

        # 提取特征和目标
        features = processed_data[feature_columns].values
        targets = processed_data['Close'].shift(-1).values  # 移除最后一个NaN

        # 移除最后一个样本（因为目标为NaN）
        features = features[:-1]
        targets = targets[:-1]

        # 数据转换处理
        # 特征转换
        features_transform = self.transform_spec.get('features', None)
        if features_transform is not None:
            features_transform = deepcopy(features_transform)
            if self.transform_spec.get('features_fit', True):
                features_transform.fit(features)
            features = features_transform.transform(features)

        # 目标转换
        targets_transform = self.transform_spec.get('targets', None)
        if targets_transform is not None:
            targets_transform = deepcopy(targets_transform)
            if self.transform_spec.get('targets_fit', True):
                # 需要将目标转换为2D数组以适应sklearn API
                targets_2d = targets.reshape(-1, 1)
                targets_transform.fit(targets_2d)
            targets = targets_transform.transform(targets_2d).flatten()

        # 转换为PyTorch张量
        features = torch.from_numpy(features).float()
        targets = torch.from_numpy(targets).float()

        return features, targets, features_transform, targets_transform, processed_data

    def __getitem__(self, index):
        """
        返回：
        - features: (sequence_length, 4) 过去sequence_length天的OHLC数据
        - target: (1,) 下一天的收盘价
        """
        if index >= len(self):
            raise IndexError()

        # 特征为[index : index+sequence_length]窗口数据
        # 目标为index+sequence_length位置的收盘价（对应下一天的预测）
        return (
            self.features[index:index + self.sequence_length],
            self.targets[index + self.sequence_length - 1]  # 调整索引对齐
        )

    def __len__(self):
        """可用样本数量 = 总数据点数 - 序列长度"""
        return len(self.targets) - self.sequence_length

    # 逆变换方法保持不变
    def inverse_transform_features(self, features):
        if self.features_transform is not None:
            device = features.device
            features = features.cpu().numpy()
            features = self.features_transform.inverse_transform(features)
            features = torch.from_numpy(features).float().to(device)
        return features

    def inverse_transform_targets(self, targets):
        if self.targets_transform is not None:
            device = targets.device
            # 需要将目标转换为2D数组以适应sklearn API
            targets = targets.cpu().numpy().reshape(-1, 1)
            targets = self.targets_transform.inverse_transform(targets)
            targets = torch.from_numpy(targets).float().to(device).flatten()
        return targets


def main():
    # ================= 配置参数 =================
    config = {
        'start_date': pd.to_datetime('2023-01-01'),
        'end_date': pd.to_datetime('2024-01-01'),
        'sequence_length': 24 * 7,  # 使用1周数据（24小时×7天）作为序列长度
        'raw_path': '../dataset/raw',
        'cache_path': '../dataset/cache',
        'batch_size': 64,
        'test_size': 0.2,
        'random_state': 42
    }

    # ================= 初始化数据集 =================
    try:
        dataset = StockDataset(
            start_date=config['start_date'],
            end_date=config['end_date'],
            sequence_length=config['sequence_length'],
            transform_spec={
                'features': StandardScaler(),
                'targets': MinMaxScaler(),
                'features_fit': True,
                'targets_fit': True
            },
            raw_path=config['raw_path'],
            cache_path=config['cache_path'],
            force_reload=False  # 首次运行设为True生成缓存
        )
    except FileNotFoundError as e:
        print(f"数据加载失败: {str(e)}")
        print("请检查以下路径是否存在CSV文件:")
        print(f"原始数据路径: {os.path.abspath(config['raw_path'])}/XAUUSD_H1.csv")
        return

    # 在main函数中添加验证
    print("\n=== 数据缓存验证 ===")
    print(f"Processed_data类型: {type(dataset.processed_data)}")
    print(f"特征数据类型: {type(dataset.features)}")

    # ================= 数据基础验证 =================
    print("\n=== 数据集基本信息 ===")
    print(f"总样本数: {len(dataset)}")
    print(f"特征维度: {dataset.features.shape[1]} 维")
    print(f"序列长度: {config['sequence_length']} 小时")
    print(f"时间范围: {dataset.processed_data.index[0]} 至 {dataset.processed_data.index[-1]}")

    # 检查第一个样本
    sample_x, sample_y = dataset[0]
    print("\n=== 首样本验证 ===")
    print(f"输入序列形状: {sample_x.shape} (应匹配 (序列长度, 特征数))")
    print(f"目标值: {sample_y.item():.2f} (应接近标准化后的价格)")

    # ================= 数据可视化 =================
    plt.figure(figsize=(16, 10))

    # 价格与技术指标可视化
    ax1 = plt.subplot(3, 1, 1)
    dataset.processed_data['Close'].plot(ax=ax1, label='Close Price')
    dataset.processed_data[['EMA25', 'EMA50']].plot(ax=ax1)
    plt.title('Price & Moving Averages')
    plt.legend()

    # MACD 指标
    ax2 = plt.subplot(3, 1, 2)
    dataset.processed_data['MACD'].plot(ax=ax2, label='MACD')
    dataset.processed_data['MACD_Signal'].plot(ax=ax2, label='Signal')
    plt.bar(dataset.processed_data.index, dataset.processed_data['MACD_Hist'], label='Histogram')
    plt.title('MACD Indicators')
    plt.legend()

    # 波动率指标
    ax3 = plt.subplot(3, 1, 3)
    dataset.processed_data['ATR'].plot(ax=ax3, label='ATR')
    dataset.processed_data['BB_Upper'].subtract(dataset.processed_data['BB_Lower']).plot(ax=ax3, label='BB Width')
    plt.title('Volatility Indicators')
    plt.legend()

    plt.tight_layout()
    plt.savefig('../output/data_visualization.png')
    print("\n可视化图表已保存至 output 目录")

    # ================= 数据管道测试 =================
    # 划分训练测试集
    train_idx, test_idx = train_test_split(
        range(len(dataset)),
        test_size=config['test_size'],
        shuffle=False  # 保持时间序列顺序
    )

    train_loader = DataLoader(
        Subset(dataset, train_idx),
        batch_size=config['batch_size'],
        shuffle=True
    )

    test_loader = DataLoader(
        Subset(dataset, test_idx),
        batch_size=config['batch_size'],
        shuffle=False
    )

    # 检查数据加载器
    batch_x, batch_y = next(iter(train_loader))
    print("\n=== 数据加载器验证 ===")
    print(f"批次输入形状: {batch_x.shape} (应匹配 (batch_size, seq_len, features))")
    print(f"批次目标形状: {batch_y.shape} (应匹配 (batch_size, 1))")

    # ================= 保存处理后的数据 =================
    processed_path = os.path.join(config['cache_path'], 'processed_data.csv')
    dataset.processed_data.to_csv(processed_path)
    print(f"\n处理后的完整数据已保存至: {processed_path}")


if __name__ == "__main__":
    # 自动创建必要目录
    os.makedirs('../output', exist_ok=True)
    os.makedirs('../dataset/cache', exist_ok=True)

    main()
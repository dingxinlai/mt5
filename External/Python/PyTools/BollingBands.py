import numpy as np
from typing import List


def is_boll_squeeze(
        upper_band: List[float],
        lower_band: List[float],
        window: int = 5,
        threshold: float = 0.1
) -> bool:
    """
    判断布林带是否处于缩口状态
    :param upper_band: 布林带上轨价格列表（按时间顺序排列，最新数据在最后）
    :param lower_band: 布林带下轨价格列表
    :param window: 检测缩口的窗口期（默认最近5个周期）
    :param threshold: 带宽缩小比例的阈值（默认10%）
    :return: True表示处于缩口，False反之
    """
    # 确保数据长度一致且足够计算
    assert len(upper_band) == len(lower_band), "上下轨数据长度不一致"
    assert len(upper_band) >= window, "数据长度不足"

    # 计算带宽（上轨 - 下轨）
    bandwidth = [u - l for u, l in zip(upper_band, lower_band)]

    # 提取最近window期的带宽数据
    recent_bandwidth = bandwidth[-window:]

    # 方法1：检查带宽是否连续递减（严格缩口）
    # is_decreasing = all(recent_bandwidth[i] > recent_bandwidth[i+1] for i in range(window-1))

    # 方法2：计算带宽变化率（更鲁棒）
    # 计算初始和最终带宽的比例变化
    change_ratio = (recent_bandwidth[0] - recent_bandwidth[-1]) / recent_bandwidth[0]

    # 方法3：线性回归斜率判断趋势（最严谨）
    x = np.arange(window)
    y = np.array(recent_bandwidth)
    slope = np.polyfit(x, y, 1)[0]  # 斜率

    # 综合判断：斜率<0且变化率超过阈值
    return slope < 0 and abs(change_ratio) > threshold

# ----------------------------- 测试用例 -----------------------------
if __name__ == "__main__":
    # 示例数据（假设最近50个周期的布林带数据）
    upper = [1827.12, 1826.84, 1826.55, 1826.25, 1825.95]  # 替换为实际上轨数据
    lower = [1809.56, 1810.40, 1811.23, 1812.05, 1812.87]  # 替换为实际下轨数据

    # 调用函数（检测最近5期是否缩口，阈值10%）
    squeeze_status = is_boll_squeeze(upper, lower, window=5, threshold=0.1)
    print(f"布林带缩口状态：{squeeze_status}")
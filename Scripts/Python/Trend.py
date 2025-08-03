import pandas as pd
import numpy as np
from scipy.signal import argrelextrema
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')


def calculate_support_resistance(indices, open_prices, high, low, close, window=50):
    """基于高低点判断的支撑压力线优化"""
    try:
        # ================== 数据预处理 ==================
        df = pd.DataFrame({
            'High': np.asarray(high, dtype=np.float64),
            'Low': np.asarray(low, dtype=np.float64)
        }, index=indices).sort_index(ascending=True)

        price_std = df['High'].subtract(df['Low']).mean()  # 使用真实波动幅度

        # ================== 稳健极值检测 ==================
        def find_robust_extrema(series, mode='high'):
            """基于高低点的极值检测"""
            comparator = np.greater if mode == 'high' else np.less
            order = max(3, int(window / 15))
            candidates = argrelextrema(series.values, comparator, order=order)[0]

            valid_points = []
            prev_val = None
            min_swing = price_std * 0.3  # 波动阈值设为平均波动30%

            # 按时间倒序处理确保结果稳定性
            for pos in sorted(candidates, reverse=True):
                current_val = series.iloc[pos]
                if prev_val and abs(current_val - prev_val) < min_swing:
                    continue
                # 排除孤立极值
                if pos > 0 and pos < len(series) - 1:
                    if comparator(current_val, series.iloc[pos - 1]) and \
                            comparator(current_val, series.iloc[pos + 1]):
                        valid_points.append(series.index[pos])
                        prev_val = current_val
            return valid_points[-window:]

        # ================== 趋势线优化核心 ==================
        def optimize_line(points, price_df, is_support):
            """高低点穿透最小化的趋势线优化"""
            best_params = (0.0, price_df['High'].mean(), -1)
            best_score = float('inf')

            # 生成邻近组合(时间跨度不超过窗口1/3)
            candidate_pairs = []
            sorted_points = sorted(points, reverse=True)[:10]  # 只考虑最近10个极值
            for i in range(len(sorted_points) - 1):
                for j in range(i + 1, len(sorted_points)):
                    if abs(sorted_points[i] - sorted_points[j]) < window // 3:
                        candidate_pairs.append((sorted_points[j], sorted_points[i]))

            # 评估每个组合
            for x1, x2 in candidate_pairs:
                # 获取高低点坐标
                y1 = price_df.loc[x1, 'High' if not is_support else 'Low']
                y2 = price_df.loc[x2, 'High' if not is_support else 'Low']
                if x2 == x1:
                    continue

                slope = (y2 - y1) / (x2 - x1)
                intercept = y1 - slope * x1

                # 穿透评估(使用High/Low)
                penetration = 0
                for idx in range(min(x1, x2), max(x1, x2) + 1):
                    if idx not in price_df.index:
                        continue
                    h = price_df.loc[idx, 'High']
                    l = price_df.loc[idx, 'Low']
                    line_val = slope * idx + intercept

                    # 支撑线不能高于最低价，压力线不能低于最高价
                    if (is_support and line_val > l) or (not is_support and line_val < h):
                        penetration += 1

                # 时间邻近性评分(最新点权重更高)
                time_score = (x2 - price_df.index[0]) / len(price_df)  # 0-1

                # 综合评分(穿透率60% + 时间邻近40%)
                score = (penetration / (x2 - x1 + 1)) * 0.6 + time_score * 0.4

                if score < best_score:
                    best_score = score
                    best_params = (slope, intercept, x1)

            # 执行智能平移
            return smart_adjust(best_params, price_df, is_support)

        def smart_adjust(params, price_df, is_support):
            """自动平移优化"""
            slope, intercept, start = params
            if start == -1:
                return params

            best_intercept = intercept
            min_pen = float('inf')
            adjust_step = price_std * 0.05
            directions = np.linspace(-5, 5, 11) if is_support else np.linspace(5, -5, 11)

            for delta in directions:
                current_intercept = intercept + delta * adjust_step
                penetration = 0
                for idx in price_df.index[start:]:
                    line_val = slope * idx + current_intercept
                    if is_support:
                        penetration += 1 if line_val > price_df.loc[idx, 'Low'] else 0
                    else:
                        penetration += 1 if line_val < price_df.loc[idx, 'High'] else 0

                if penetration < min_pen:
                    min_pen = penetration
                    best_intercept = current_intercept

            return (slope, best_intercept, start)

        # ================== 主逻辑执行 ==================
        high_points = find_robust_extrema(df['High'], 'high')
        low_points = find_robust_extrema(df['Low'], 'low')

        # 生成趋势线(压力线用high_points，支撑线用low_points)
        resist_params = optimize_line(high_points, df, False)
        support_params = optimize_line(low_points, df, True)

        # 最终验证(最新3根K线至少2根符合)
        def is_valid(params, is_support):
            slope, intercept, start = params
            if start == -1 or abs(slope) < 1e-5:
                return False

            valid_count = 0
            for idx in df.index[-3:]:
                line_val = slope * idx + intercept
                if is_support:
                    valid_count += 1 if line_val <= df.loc[idx, 'Low'] else 0
                else:
                    valid_count += 1 if line_val >= df.loc[idx, 'High'] else 0
            return valid_count >= 2

        final_resist = resist_params if is_valid(resist_params, False) else (0.0, df['High'].mean(), -1)
        final_support = support_params if is_valid(support_params, True) else (0.0, df['Low'].mean(), -1)

        return (
            [round(final_support[0], 5), round(final_support[1], 5), float(final_support[2])],
            [round(final_resist[0], 5), round(final_resist[1], 5), float(final_resist[2])]
        )

    except Exception as e:
        logging.error(f"计算失败: {str(e)}", exc_info=True)
        return (
            [0.0, 0.0, -1.0],
            [0.0, 0.0, -1.0]
        )


# 测试用例
if __name__ == "__main__":
    # 问题3的测试数据
    test_indices = np.arange(6)
    test_high = [2800, 2715, 2700, 2710, 2720, 2730]
    test_low = [h - 10 for h in test_high]

    _, resist = calculate_support_resistance(test_indices, None, test_high, test_low, None, 6)
    print(f"压力线方程: y = {resist[0]:.2f}x + {resist[1]:.2f}")  # 预期连接2715和2720，斜率≈(2720-2715)/(4-1)=1.67
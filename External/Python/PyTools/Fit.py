import numpy as np
from sklearn.linear_model import LinearRegression
from sklearn.metrics import r2_score
import logging
from datetime import datetime
import traceback
import os

current_date = datetime.now().strftime("%Y-%m-%d")
mt5_path = os.environ['MT5_HOME']
log_file_path = fr'{mt5_path}\Logs\Python_{current_date}.log'

if not os.path.exists(log_file_path):
    # Create the file if it does not exist
    open(log_file_path, 'w').close()

logging.basicConfig(
    filename=log_file_path,
    level=logging.DEBUG,  # 开启DEBUG级别以查看详细参数
    format='%(asctime)s - %(name)s - %(levelname)s - [%(funcName)s] - %(message)s',
    encoding='utf-8'
)
logger = logging.getLogger('PriceFitter')


def log_input_details(x, y1, y2, max_samples=5):
    """记录输入参数的结构化信息"""
    logger.debug("【输入参数分析】")
    logger.debug(f"X数组类型: {type(x)}, 长度: {len(x)}")
    logger.debug(f"Y1数组类型: {type(y1)}, 长度: {len(y1)}")
    logger.debug(f"Y2数组类型: {type(y2)}, 长度: {len(y2)}")

    # 安全样本记录
    def safe_samples(data, name):
        try:
            samples = data[:max_samples] if len(data) > max_samples else data
            return f"{name}_样本: {samples}" + ("..." if len(data) > max_samples else "")
        except:
            return f"{name}_样本格式异常"

    logger.debug(safe_samples(x, "X"))
    logger.debug(safe_samples(y1, "Y1"))
    logger.debug(safe_samples(y2, "Y2"))

    # 增强型差异统计
    try:
        y1_arr = np.array(y1, dtype=np.float64)
        y2_arr = np.array(y2, dtype=np.float64)

        if len(y1_arr) != len(y2_arr):
            logger.warning(f"价格数组长度不一致 | Y1: {len(y1_arr)} vs Y2: {len(y2_arr)}")
            return

        diffs = y1_arr - y2_arr
        if np.isnan(diffs).any():
            logger.warning(f"存在无效值(NaN) | 无效值数量: {np.isnan(diffs).sum()}")

        logger.debug(f"价格差异统计 | 均值: {np.nanmean(diffs):.4f} | 标准差: {np.nanstd(diffs):.4f}")

    except Exception as e:
        logger.warning(f"差异分析失败: {str(e)}", exc_info=True)

def calculate_fit(x_array, y_array, y_array2):
    """返回包含R²系数、斜率和截距的元组"""
    logger.info(f"函数调用开始")

    try:
        # 记录完整输入参数细节
        log_input_details(x_array, y_array, y_array2)

        # 数据预处理
        x = np.array(x_array, dtype=np.int64).reshape(-1, 1)
        y_avg = (np.array(y_array) + np.array(y_array2)) / 2

        # 有效性校验
        if len(x) < 2:
            logger.warning(f"数据量不足 | 当前数据点: {len(x)} | 要求最低2个")
            return (-1.0, 0.0, 0.0)

        if np.var(x) == 0:
            logger.warning(f"时间序列冻结 | 所有时间点: {x[0][0]} | 数据量: {len(x)}")
            return (-1.0, 0.0, 0.0)

        # 模型训练
        logger.info("开始模型训练...")
        model = LinearRegression()
        model.fit(x, y_avg)
        logger.debug(f"训练数据形状: X={x.shape}, y={y_avg.shape}")

        # 获取参数
        coef = float(model.coef_[0])
        intercept = float(model.intercept_)
        logger.info(f"模型参数 | 斜率: {coef:.6f} | 截距: {intercept:.6f}")

        # 计算指标
        y_pred = model.predict(x)
        r2 = float(r2_score(y_avg, y_pred))
        logger.info(f"评估结果 | R²: {r2:.4f} | 预测范围: [{y_pred.min():.2f}, {y_pred.max():.2f}]")

        return (r2, coef, intercept)

    except ValueError as ve:
        logger.error(f"数值异常 | 错误信息: {str(ve)} | 输入样本: "
                     f"X={x_array[:3]} | Y1={y_array[:3]} | Y2={y_array2[:3]}")
        return (-1.0, 0.0, 0.0)

    except Exception as e:
        logger.error(f"未处理异常 | 类型: {type(e)} | 信息: {str(e)}\n"
                     f"完整输入: X={x_array} | Y1={y_array} | Y2={y_array2}\n"
                     f"堆栈追踪: {traceback.format_exc()}")
        return (-1.0, 0.0, 0.0)
    finally:
        logger.info("函数调用结束\n" + "=" * 60)


if __name__ == "__main__":
    # 原始输入数据
    time_data = [
        "D'2024.08.05 12:00:00'",
        "D'2024.08.07 00:00:00'",
        "D'2024.08.07 20:00:00'",
        "D'2024.08.12 00:00:00'",
        "D'2024.08.14 12:00:00'"
    ]

    price1 = [
        2364.389999999984866008,
        2378.949999999999818101,
        2380.860000000000127329,
        2423.73000000000001819,
        2450.549999999988358468
    ]

    price2 = [
        2364.389999999984866008,
        2383.780000000000200089,
        2383.949999999999818101,
        2426.139999999999872671,
        2450.549999999988358468
    ]


    # 时间戳转换函数
    def convert_time(time_str):
        from datetime import datetime
        clean_str = time_str.strip("D'").replace("'", "")
        dt = datetime.strptime(clean_str, "%Y.%m.%d %H:%M:%S")
        return int(dt.timestamp())


    try:
        # 执行转换和计算
        x_array = [convert_time(t) for t in time_data]
        y_array = [float(p) for p in price1]
        y_array2 = [float(p) for p in price2]

        # 调用拟合函数
        r2, coef, intercept = calculate_fit(x_array, y_array, y_array2)

        # 结果格式化输出
        print("\n" + "=" * 40)
        print(f"{'拟合结果分析':^40}")
        print("=" * 40)
        print(f"R²系数: {r2:.4f} ({'优秀' if r2 > 0.9 else '良好' if r2 > 0.7 else '一般' if r2 > 0.4 else '较差'})")
        print(f"斜率: {coef:.6f} 价格/秒 | {coef * 86400:.2f} 价格/天")
        print(f"截距: {intercept:.4f}")
        print(f"拟合方程: price = {coef:.6f} * t + {intercept:.4f}")
        print("=" * 40)

        # 预测示例
        sample_time = x_array[0] + 86400 * 3  # 3天后
        predicted = coef * sample_time + intercept
        print(f"\n预测示例（3天后）：")
        print(f"时间戳: {sample_time}")
        print(f"预测价格: {predicted:.2f}")

    except Exception as e:
        print(f"\n错误: {str(e)}")
        print("返回默认值: (-1.0, 0.0, 0.0)")
        print(-1.0, 0.0, 0.0)
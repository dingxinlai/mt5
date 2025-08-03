import yaml
import os
from typing import Any, List
import logging
import pandas as pd

# 配置日志记录
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# 获取 MT5_HOME 环境变量
MT5_HOME = os.getenv('MT5_HOME')
if not MT5_HOME:
    logging.error("环境变量 MT5_HOME 未设置，请检查。")
    raise ValueError("环境变量 MT5_HOME 未设置，请检查。")

# 定义不同 namespace 对应的配置文件名称
_CONFIG_FILE_NAMES = {
    "GLB": "glb_config.yaml",
    "IDC": "idc_config.yaml",
    "TRD": "trd_config.yaml",
}

# 根据 MT5_HOME 动态构建配置文件路径
_CONFIG_PATHS = {
    namespace: os.path.join(MT5_HOME, 'Files', file_name)
    for namespace, file_name in _CONFIG_FILE_NAMES.items()
}

# 配置缓存
_CONFIG_CACHE = {}


def _load_config(namespace: str) -> dict:
    """根据 namespace 加载并缓存 YAML 配置文件"""
    if namespace in _CONFIG_CACHE:
        return _CONFIG_CACHE[namespace]

    config_path = _CONFIG_PATHS.get(namespace)
    if not config_path:
        logging.warning(f"未找到 {namespace} 对应的配置文件路径")
        return {}

    if not os.path.exists(config_path):
        logging.warning(f"配置文件 {config_path} 不存在")
        return {}

    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            config = yaml.safe_load(f) or {}
            _CONFIG_CACHE[namespace] = config  # 存入缓存
            return config
    except Exception as e:
        logging.error(f"加载配置文件 {config_path} 时出错: {e}")
        return {}


def nested_get(d: dict, keys: list) -> Any:
    """支持字典和列表的多级嵌套查询"""
    current = d
    for k in keys:
        if isinstance(current, dict):
            current = current.get(convert_string_to_number(k))
        elif isinstance(current, list):
            try:
                current = current[int(k)]  # 将字符串 key 转换为列表索引
            except (ValueError, IndexError, TypeError):
                return None
        else:
            return None
        if current is None:
            break
    return current


def get_config(namespace: str, key: str) -> bytes:
    """获取指定路径的配置值（返回 bytes 类型）"""
    key_parts = key.split('.') if key else []
    config = _load_config(namespace)
    value = nested_get(config, key_parts)
    return str(value).encode('utf-8') if value is not None else b''


def get_list(namespace: str, key: str) -> List[str]:
    """
    获取指定路径下的直接子键（字典键或列表索引）

    示例：
    假设配置结构为 a.b.c.d 和 a.b.c.e，调用 get_list("namespace", "a.b.c") 返回 ["d", "e"]
    """
    key_parts = key.split('.') if key else []
    config = _load_config(namespace)
    node = nested_get(config, key_parts)

    if isinstance(node, dict):
        return list(node.keys())
    elif isinstance(node, list):
        return [str(i) for i in range(len(node))]  # 返回字符串形式的索引
    else:
        return []


# ----------------------------- 系数读取部分 -----------------------------
_COEF_DF = None  # Excel 数据缓存


def get_coef(indicator: str, period: str) -> float:
    """从 Excel 文件读取系数值（带缓存机制）"""
    global _COEF_DF

    if _COEF_DF is None:  # 首次加载时读取
        excel_path = os.path.join(MT5_HOME, 'Files', 'coefficient.xlsx')
        if not os.path.exists(excel_path):
            logging.error(f"Excel 文件 {excel_path} 不存在")
            return 0.0

        try:
            _COEF_DF = pd.read_excel(excel_path, index_col=0)
        except Exception as e:
            logging.error(f"读取 Excel 文件失败: {e}")
            return 0.0

    try:
        # 检查列名和索引是否存在
        if period in _COEF_DF.columns and indicator in _COEF_DF.index:
            coef = _COEF_DF.at[indicator, period]
            return float(coef) if pd.notna(coef) else 0.0
        else:
            logging.warning(f"无效的指标或周期: {indicator}@{period}")
            return 0.0
    except Exception as e:
        logging.error(f"读取系数时发生意外错误: {e}")
        return 0.0


def convert_string_to_number(s):
    s = s.strip()  # 去除首尾空格
    if not s:
        return s  # 空字符串直接返回

    # 尝试转为整数
    try:
        return int(s)
    except ValueError:
        pass

    # 尝试转为浮点数
    try:
        num = float(s)
        # 检查浮点数是否为整数（如 123.0 -> 123）
        if num.is_integer():
            return int(num)
        return num
    except ValueError:
        pass

    # 非数字返回原字符串
    return s

# ----------------------------- 测试用例 -----------------------------
if __name__ == "__main__":
    # 示例配置结构测试
    try:
        print("测试 get_list:")
        print(get_list("IDC", "MA.M1"))  # 预期输出 ['periods', '# 预期输出 ['w1', 'w2']

        print("\n测试 get_config:")
        print(get_config("IDC", "MA.M15.10.MA_PERIOD"))  # 预期值 5 的 bytes 形式

        print("\n测试 get_coef:")
        print(get_coef("MACD", "H1"))  # 根据实际 Excel 内容输出
    except Exception as e:
        logging.error(f"测试运行失败: {e}")
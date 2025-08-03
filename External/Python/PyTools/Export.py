import os
import pandas as pd
from openpyxl import load_workbook


def create_excel(filename: str, columns: list):
    """由 Python 完全控制文件路径"""
    # 1. 获取 MT5_HOME 环境变量
    mt5_home = os.getenv("MT5_HOME")
    if not mt5_home:
        raise ValueError("MT5_HOME 环境变量未设置")

    # 2. 构建导出目录 {MT5_HOME}/Export
    export_dir = os.path.join(mt5_home, "Export")
    os.makedirs(export_dir, exist_ok=True)  # 自动创建目录

    # 3. 生成完整文件路径
    full_path = os.path.join(export_dir, f"{filename}.xlsx")

    # 4. 创建 Excel 文件
    df = pd.DataFrame(columns=columns)
    df.to_excel(full_path, index=False)
    print(f"文件已创建: {full_path}")


def append_to_excel(filename: str, row_data: list):
    """追加数据到指定文件"""
    # 1. 获取 MT5_HOME
    mt5_home = os.getenv("MT5_HOME")
    if not mt5_home:
        raise ValueError("MT5_HOME 未设置")

    # 2. 构建完整路径
    full_path = os.path.join(mt5_home, "Export", f"{filename}.xlsx")
    if not os.path.exists(full_path):
        raise FileNotFoundError(f"文件 {full_path} 不存在")

    # 3. 追加数据
    df_existing = pd.read_excel(full_path)
    new_row = pd.DataFrame([row_data], columns=df_existing.columns)
    df_combined = pd.concat([df_existing, new_row], ignore_index=True)

    # 4. 保存（避免覆盖原有数据）
    with pd.ExcelWriter(full_path, engine='openpyxl', mode='a', if_sheet_exists='overlay') as writer:
        df_combined.to_excel(writer, index=False, header=(not df_existing.shape[0]))
    print(f"数据已追加到 {full_path}")
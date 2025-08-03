# 设置BOOST_PATH环境变量
$boostPath = "C:\Program Files\ATFXGM MT5 Terminal\MQL5\External\Python\boost_1_87_0"
[Environment]::SetEnvironmentVariable("BOOST_PATH", $boostPath, [System.EnvironmentVariableTarget]::Machine)

# 设置PYTHON_PATH环境变量
$pythonPath = "C:\Users\Administrator\AppData\Local\Programs\Python\Python310"
[Environment]::SetEnvironmentVariable("PYTHON_PATH", $pythonPath, [System.EnvironmentVariableTarget]::Machine)

# 输出设置后的环境变量值，用于验证
$newBoostPath = [Environment]::GetEnvironmentVariable("BOOST_PATH", [System.EnvironmentVariableTarget]::Machine)
$newPythonPath = [Environment]::GetEnvironmentVariable("PYTHON_PATH", [System.EnvironmentVariableTarget]::Machine)

Write-Host "BOOST_PATH已设置为: $newBoostPath"
Write-Host "PYTHON_PATH已设置为: $newPythonPath"
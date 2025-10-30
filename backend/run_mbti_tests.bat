@echo off
echo 正在运行MBTI API测试...

REM 检查Node.js是否安装
node --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo 错误: 未找到Node.js，请先安装Node.js
    pause
    exit /b 1
)

REM 检查axios是否安装
if not exist "node_modules\axios" (
    echo 正在安装axios...
    npm install axios
)

REM 运行测试
echo 开始测试MBTI API功能...
node test_mbti_api.js

echo.
echo 测试完成！
pause

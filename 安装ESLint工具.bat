@echo off
chcp 65001 >nul
echo ========================================
echo 代码审查工具 - ESLint 安装脚本
echo ========================================
echo.

echo [1/4] 安装后端 ESLint...
cd backend
if not exist package.json (
    echo 错误: backend/package.json 不存在
    pause
    exit /b 1
)

echo 正在安装 ESLint...
call npm install --save-dev eslint
echo 后端 ESLint 安装完成！
echo.
echo 请运行以下命令初始化 ESLint 配置：
echo   cd backend
echo   npx eslint --init
echo.
cd ..

echo [2/4] 为 Web Admin 创建 package.json...
cd web_admin
if not exist package.json (
    echo 正在创建 package.json...
    call npm init -y
    echo package.json 创建完成！
) else (
    echo package.json 已存在，跳过创建
)
echo.

echo [3/4] 安装 Web Admin ESLint...
echo 正在安装 ESLint...
call npm install --save-dev eslint
echo Web Admin ESLint 安装完成！
echo.
echo 请运行以下命令初始化 ESLint 配置：
echo   cd web_admin
echo   npx eslint --init
echo.
cd ..

echo [4/4] 验证安装...
echo.
echo 检查后端 ESLint...
cd backend
if exist node_modules\eslint (
    echo ✓ 后端 ESLint 安装成功
) else (
    echo ✗ 后端 ESLint 安装失败
)
cd ..

echo.
echo 检查 Web Admin ESLint...
cd web_admin
if exist node_modules\eslint (
    echo ✓ Web Admin ESLint 安装成功
) else (
    echo ✗ Web Admin ESLint 安装失败
)
cd ..

echo.
echo ========================================
echo 安装完成！
echo ========================================
echo.
echo 下一步操作：
echo 1. 进入 backend 目录，运行: npx eslint --init
echo 2. 进入 web_admin 目录，运行: npx eslint --init
echo 3. 运行代码审查：
echo    - Flutter: flutter analyze
echo    - 后端: cd backend ^&^& npx eslint .
echo    - Web Admin: cd web_admin ^&^& npx eslint .
echo.
pause





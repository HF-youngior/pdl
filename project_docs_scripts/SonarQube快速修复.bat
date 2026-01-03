@echo off
echo ========================================
echo SonarQube快速修复脚本
echo ========================================

echo 检查SonarQube服务状态...
netstat -ano | findstr :9000 >nul
if %errorlevel% neq 0 (
    echo 错误: SonarQube服务未运行，请先启动服务
    echo 正在启动SonarQube服务...
    call "F:\pdl\启动SonarQube服务.bat"
    if %errorlevel% neq 0 (
        echo 启动失败，请手动检查
        pause
        exit /b 1
    )
)

echo SonarQube服务正在运行
echo.
echo 请在浏览器中打开 http://localhost:9000
echo 确保已创建项目密钥为 'pdl' 的项目
echo.
echo 当前使用的Token: sqp_5d7884ce3957f7c0f5449d1a8d5a9bd1ec355d49
echo.
echo 如果Token无效，请:
echo 1. 登录SonarQube Web界面
echo 2. 生成新Token
echo 3. 更新sonar-project.properties文件
echo.
echo 尝试使用管理员权限创建项目...
echo 正在打开SonarQube Web界面...
start http://localhost:9000

echo.
echo 请按照以下步骤操作:
echo 1. 使用admin/admin登录
echo 2. 创建项目密钥为'pdl'的项目
echo 3. 生成新的Token
echo 4. 更新sonar-project.properties文件中的sonar.login值
echo 5. 重新运行扫描命令
echo.
pause
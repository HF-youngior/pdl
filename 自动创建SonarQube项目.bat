@echo off
chcp 65001 >nul
echo ========================================
echo SonarQube项目自动创建脚本
echo ========================================

echo 设置环境变量...
set SONAR_HOME=D:\sonarqube-25.12.0.117093
set SONAR_SCANNER_HOME=D:\sonar-scanner-4.8.0.2856

echo 检查SonarQube服务状态...
netstat -ano | findstr :9000 >nul
if %errorlevel% neq 0 (
    echo 错误: SonarQube服务未运行，正在启动...
    call "%SONAR_HOME%\bin\windows-x86-64\StartSonar.bat"
    timeout /t 60 /nobreak >nul
    netstat -ano | findstr :9000 >nul
    if %errorlevel% neq 0 (
        echo 错误: SonarQube服务启动失败
        pause
        exit /b 1
    )
)

echo SonarQube服务正在运行
echo.

echo 使用管理员凭据创建项目...
echo 管理员用户名: admin
echo 管理员密码: asdfgh0625@YYH
echo.

echo 正在打开SonarQube Web界面...
start http://localhost:9000

echo.
echo 请按照以下步骤手动创建项目:
echo 1. 在打开的浏览器中使用以下凭据登录:
echo    用户名: admin
echo    密码: asdfgh0625@YYH
echo.
echo 2. 点击"Create new project"或"+"按钮
echo 3. 选择"Manually"（手动创建）
echo 4. 输入项目密钥: pdl
echo 5. 输入项目名称: PDL企业管理系统
echo 6. 点击"Set up"按钮
echo 7. 选择项目类型（例如："Other"或"Custom"）
echo 8. 选择分析方式（选择"Locally"或"Use a specific scanner"）
echo 9. 选择"SonarScanner"作为分析工具
echo 10. 点击"Continue"然后"Finish"完成项目创建
echo.
echo 完成项目创建后，按任意键继续扫描...
pause

echo.
echo 使用新Token进行扫描...
echo Token: sqp_ca5888234671bfe3514420a0e8ce3dbedee3782d
echo.

"%SONAR_SCANNER_HOME%\bin\sonar-scanner.bat" -D sonar.login=sqp_ca5888234671bfe3514420a0e8ce3dbedee3782d

if %errorlevel% equ 0 (
    echo.
    echo 扫描成功完成!
    echo 请访问 http://localhost:9000/dashboard?id=pdl 查看扫描结果
) else (
    echo.
    echo 扫描失败，请检查错误信息
    echo 如果仍然提示权限问题，请:
    echo 1. 确认项目已在SonarQube中创建
    echo 2. 检查Token是否有足够权限
    echo 3. 尝试使用管理员Token重新扫描
)

echo.
pause
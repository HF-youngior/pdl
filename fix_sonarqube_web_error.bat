@echo off
chcp 65001 >nul
echo 🔧 SonarQube Web界面错误修复工具
echo =====================================
echo.

echo 📋 错误分析:
echo 错误类型: DOM操作异常
echo 错误描述: "removeChild"操作失败 - 节点不是指定父节点的子节点
echo 影响范围: SonarQube Web界面动态更新功能
echo.

echo 🔍 可能的原因:
echo 1. 浏览器缓存问题
echo 2. SonarQube版本兼容性问题  
echo 3. JavaScript库冲突
echo 4. 页面组件状态异常
echo.

echo 🛠️ 解决方案:
echo.

echo 方案1: 清理浏览器缓存并强制刷新
echo    - 按 Ctrl+Shift+Delete 打开清理工具
echo    - 清理所有缓存和Cookie
echo    - 按 Ctrl+F5 强制刷新页面
echo.

echo 方案2: 使用无痕模式访问
echo    - 打开浏览器无痕模式
echo    - 访问 http://localhost:9000
echo    - 登录SonarQube
echo.

echo 方案3: 重启SonarQube服务
echo 正在执行重启操作...
echo.

cd /d D:\sonarqube-25.12.0.117093
echo 停止SonarQube服务...
call stopsonar.bat
timeout /t 10 /nobreak >nul

echo 启动SonarQube服务...
call startsonar.bat
echo.

echo 方案4: 检查SonarQube日志
echo 查看最新日志以获取更多错误信息...
echo.

if exist "logs\sonar.log" (
    echo 📄 最新日志内容:
    echo ----------------------------------------
    powershell "Get-Content 'logs\sonar.log' -Tail 20"
    echo ----------------------------------------
) else (
    echo ⚠️  日志文件不存在
)

echo.
echo 方案5: 浏览器兼容性检查
echo 推荐使用以下浏览器:
echo - Chrome 90+
echo - Firefox 88+
echo - Edge 90+
echo.

echo ✅ 修复完成建议:
echo 1. 清理浏览器缓存后重新访问
echo 2. 如果问题持续，尝试其他浏览器
echo 3. 检查浏览器控制台是否有其他JavaScript错误
echo 4. 确保SonarQube版本与浏览器兼容
echo.

echo 🌐 访问地址: http://localhost:9000
echo 👤 默认账号: admin / admin
echo.

pause
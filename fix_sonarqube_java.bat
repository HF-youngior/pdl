@echo off
chcp 65001 >nul
echo ========================================
echo SonarQube Java版本兼容性修复工具
echo ========================================
echo.

echo 正在检查当前Java版本...
java -version
echo.

echo 正在检查SonarQube配置文件...
set SONAR_WRAPPER=D:\sonarqube-9.9.0.65466\bin\windows-x86-64\lib\SonarServiceWrapper.xml

if not exist "%SONAR_WRAPPER%" (
    echo 错误: SonarQube配置文件不存在
    echo 请确认SonarQube安装路径正确
    pause
    exit /b 1
)

echo 发现配置文件: %SONAR_WRAPPER%
echo.

echo 方案1: 手动修改Java路径
echo ----------------------------------------
echo 请按照以下步骤手动修改配置文件:
echo 1. 用管理员权限打开记事本
echo 2. 打开文件: %SONAR_WRAPPER%
echo 3. 找到这一行: ^<executable^>java.exe^</executable^>
echo 4. 替换为: ^<executable^>C:\Program Files\Java\jdk-21\bin\java.exe^</executable^>
echo 5. 保存文件
echo.

echo 方案2: 设置JAVA_HOME环境变量
echo ----------------------------------------
echo 这是最推荐的解决方案
echo.

echo 检查当前JAVA_HOME...
echo 当前JAVA_HOME: %JAVA_HOME%
echo.

echo 请按照以下步骤设置JAVA_HOME:
echo 1. 右键"此电脑" -^> "属性"
echo 2. 点击"高级系统设置"
echo 3. 点击"环境变量"
echo 4. 在"系统变量"中点击"新建"
echo 5. 变量名: JAVA_HOME
echo 6. 变量值: C:\Program Files\Java\jdk-21
echo 7. 确保Path变量包含: %%JAVA_HOME%%\bin
echo.

echo 方案3: 下载兼容的SonarQube版本
echo ----------------------------------------
echo SonarQube 9.9.0与Java 21不完全兼容
echo 建议下载SonarQube 10.x版本或安装Java 17
echo.

echo 修复完成后的验证步骤:
echo ----------------------------------------
echo 1. 运行: D:\sonarqube-9.9.0.65466\bin\windows-x86-64\StartSonar.bat
echo 2. 等待启动完成(约2-3分钟)
echo 3. 访问: http://localhost:9000
echo 4. 检查日志: D:\sonarqube-9.9.0.65466\logs\sonar.log
echo.

echo 现在为您打开配置文件进行手动编辑...
echo 请按照上述方案1的步骤操作
echo.

notepad "%SONAR_WRAPPER%"

echo.
echo 修复脚本执行完毕
echo 请根据上述方案完成修复后重新启动SonarQube
pause
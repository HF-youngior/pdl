# SonarQube项目配置与使用指南

## 当前问题分析

从错误信息看，扫描器运行时遇到权限问题：
```
ERROR: You're not authorized to analyze this project or the project doesn't exist on SonarQube and you're not authorized to create it. Please contact an administrator.
```

## 解决方案

### 方案1：在SonarQube Web界面中创建项目

1. 打开浏览器访问：http://localhost:9000
2. 使用管理员账户登录（默认：admin/admin）
3. 点击"Create new project"或"创建项目"
4. 输入项目密钥：`pdl`
5. 输入项目名称：`PDL企业管理系统`
6. 选择"Manually"或"手动"设置
7. 完成项目创建后，使用您的Token进行扫描

### 方案2：生成新的Token

1. 登录SonarQube Web界面
2. 点击右上角头像 > "My Account" > "Security"
3. 在"Generate Tokens"部分输入Token名称（如：pdl-scanner）
4. 点击"Generate"按钮
5. 复制生成的Token（注意：Token只显示一次，请妥善保存）
6. 更新sonar-project.properties文件中的sonar.login值

### 方案3：使用管理员Token

如果您有管理员权限，可以：

1. 使用管理员账户登录SonarQube
2. 生成管理员Token
3. 更新扫描命令：
   ```
   sonar-scanner -D sonar.login=您的管理员Token
   ```

## 验证步骤

1. 确保SonarQube服务正在运行：
   ```
   netstat -ano | findstr :9000
   ```

2. 确保可以访问SonarQube Web界面：
   打开浏览器访问 http://localhost:9000

3. 检查项目配置：
   ```
   sonar-scanner -D sonar.login=您的Token -D sonar.projectKey=pdl -D sonar.host.url=http://localhost:9000
   ```

## 常见问题

### 1. Token无效
- 确保Token没有过期
- 确保Token复制完整，没有多余空格
- 尝试生成新Token

### 2. 项目不存在
- 在SonarQube Web界面中手动创建项目
- 确保项目密钥与配置文件中的sonar.projectKey一致

### 3. 网络连接问题
- 确保SonarQube服务正在运行
- 检查防火墙设置
- 确保可以使用浏览器访问SonarQube

## 快速修复脚本

创建一个快速修复脚本，自动检查并尝试解决常见问题：

```batch
@echo off
echo ========================================
echo SonarQube快速修复脚本
echo ========================================

echo 检查SonarQube服务状态...
netstat -ano | findstr :9000 >nul
if %errorlevel% neq 0 (
    echo 错误: SonarQube服务未运行，请先启动服务
    pause
    exit /b 1
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
pause
```

## 下一步操作

1. 按照上述方案之一解决权限问题
2. 重新运行扫描命令
3. 查看扫描结果并修复发现的问题

## 联系支持

如果问题仍然存在，请提供以下信息：
- SonarQube服务器版本
- 使用的Token权限级别
- 完整的错误日志
- sonar-project.properties文件内容
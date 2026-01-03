# SonarQube项目创建指南

## 问题分析

您已经创建了新的Token (sqp_ca5888234671bfe3514420a0e8ce3dbedee3782d)，但扫描仍然失败，错误信息为：
```
ERROR: You're not authorized to analyze this project or the project doesn't exist on SonarQube and you're not authorized to create it.
```

这表明SonarQube服务器上还没有创建项目密钥为'pdl'的项目，或者您的Token没有创建项目的权限。

## 解决方案

### 步骤1：登录SonarQube

1. 打开浏览器访问：http://localhost:9000
2. 使用管理员账户登录（默认：admin/admin）

### 步骤2：创建项目

1. 点击页面上的"Create new project"或"+"按钮
2. 选择"Manually"（手动创建）
3. 输入项目密钥（Project key）：`pdl`
4. 输入项目名称（Display name）：`PDL企业管理系统`
5. 点击"Set up"按钮

### 步骤3：配置项目

1. 选择您的项目类型（例如："Other"或"Custom"）
2. 选择分析方式（选择"Locally"或"Use a specific scanner"）
3. 选择"SonarScanner"作为分析工具
4. 点击"Continue"

### 步骤4：获取项目信息

1. 页面会显示项目密钥和名称
2. 确认项目密钥为`pdl`
3. 点击"Finish"完成项目创建

### 步骤5：验证项目创建

1. 在顶部菜单点击"Projects"
2. 确认可以看到"PDL企业管理系统"项目
3. 点击项目名称进入项目页面

### 步骤6：重新运行扫描

1. 回到命令行
2. 运行以下命令：
   ```
   F:\pdl\使用新Token扫描.bat
   ```

## 替代方案：使用管理员权限

如果您有管理员权限，也可以尝试以下方法：

1. 使用admin账户登录SonarQube
2. 生成管理员Token
3. 更新sonar-project.properties文件中的sonar.login值
4. 重新运行扫描

## 常见问题

### 1. Token权限不足
- 确保Token有"Execute Analysis"权限
- 如果不确定，可以生成新的Token并勾选所有权限

### 2. 项目密钥不匹配
- 确保项目密钥与sonar-project.properties文件中的sonar.projectKey完全一致
- 注意大小写和特殊字符

### 3. 网络连接问题
- 确保SonarQube服务正在运行
- 检查防火墙设置
- 确保可以使用浏览器访问SonarQube

## 快速验证脚本

创建一个快速验证脚本，检查项目是否存在：

```batch
@echo off
echo Checking if project 'pdl' exists on SonarQube...
curl -s -u sqp_ca5888234671bfe3514420a0e8ce3dbedee3782d: http://localhost:9000/api/projects/search?projects=pdl
echo.
pause
```

如果项目存在，您会看到项目的JSON信息；如果不存在，您会看到一个空的项目列表。

## 下一步操作

1. 按照上述步骤在SonarQube Web界面中创建项目
2. 重新运行扫描脚本
3. 查看扫描结果并修复发现的问题

## 联系支持

如果问题仍然存在，请提供：
- SonarQube服务器版本
- 使用的Token权限级别
- 完整的错误日志
- sonar-project.properties文件内容
# SonarQube静态安全测试详细指南

## 2.1 工具配置与执行

### 工具名称：SonarQube

### 扫描对象：
- **后端代码**：Node.js + Express (JavaScript)
- **前端代码**：Flutter/Dart
- **Web管理端**：HTML静态文件

### 环境要求：
1. **SonarQube Server** (推荐版本：SonarQube 9.9+)
2. **SonarQube Scanner** (命令行工具)
3. **Java Runtime Environment** (JRE 11+)
4. **SonarDart插件** (用于Flutter/Dart代码扫描)

### 安装步骤：

#### 1. 安装SonarQube Server
```bash
# 下载SonarQube
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.0.65466.zip

# 解压并启动
unzip sonarqube-9.9.0.65466.zip
cd sonarqube-9.9.0.65466/bin/windows-x86-64
./StartSonar.bat
```

#### 2. 安装SonarQube Scanner
```bash
# 下载Scanner
wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.8.0.2856.zip

# 配置环境变量
set SONAR_SCANNER_HOME=C:\sonar-scanner
set PATH=%PATH%;%SONAR_SCANNER_HOME%\bin
```

#### 3. 安装SonarDart插件
1. 访问：http://localhost:9000/admin/marketplace
2. 搜索"SonarDart"
3. 点击安装并重启SonarQube

### 执行情况：

#### 配置文件已创建：
- **文件位置**：`f:\pdl\sonar-project.properties`
- **项目Key**：`PDL-Enterprise-Management`
- **扫描范围**：backend/ 和 lib/ 目录

#### 执行脚本已创建：
- **文件位置**：`f:\pdl\run_sonarqube_scan.bat`
- **功能**：自动化扫描执行

#### 扫描命令：
```bash
cd f:\pdl
run_sonarqube_scan.bat
```

#### 预期结果：
- **总代码行数**：约15,000+ 行
- **扫描文件数**：50+ 个文件
- **主要语言**：JavaScript (80%), Dart (20%)

### SonarQube项目仪表盘主界面：
```
[此处插入：SonarQube 项目仪表盘主界面的截图，证明已安装并成功运行扫描]

预期截图内容：
- 项目名称：PDL企业管理系统
- 代码质量评级：A/B/C/D
- 漏洞数量统计
- 安全热点数量
- 代码覆盖率
- 技术债务比例
```

## 2.2 漏洞发现与分析

### 预期发现的安全问题类型：

#### 漏洞1：硬编码敏感信息
- **问题描述**：数据库连接字符串和API密钥直接写在代码中
- **严重等级**：Critical
- **代码位置**：server_enterprise.js:30-40
- **风险**：敏感信息泄露，未授权访问

#### 漏洞2：SQL注入风险
- **问题描述**：动态SQL拼接未使用参数化查询
- **严重等级**：Major
- **代码位置**：多个数据库操作函数
- **风险**：数据库被恶意操作

#### 漏洞3：输入验证不足
- **问题描述**：用户输入未进行充分验证和清理
- **严重等级**：Major
- **代码位置**：API接口处理函数
- **风险**：XSS攻击、注入攻击

### 扫描后需要分析的内容：

#### 安全热点 (Security Hotspots)：
- 认证和授权机制
- 敏感数据处理
- 加密算法使用
- 输入验证和输出编码

#### 代码质量问题：
- 代码复杂度过高
- 重复代码
- 测试覆盖率不足
- 代码规范违反

### 修复建议模板：

#### 对于硬编码敏感信息：
```javascript
// 修复前
const dbConfig = {
  host: 'rm-2zeoa1b89ga70ikpifo.mysql.rds.aliyuncs.com',
  password: 'Pdl1234567'
};

// 修复后
const dbConfig = {
  host: process.env.DB_HOST,
  password: process.env.DB_PASSWORD
};
```

#### 对于SQL注入风险：
```javascript
// 修复前
const query = `SELECT * FROM users WHERE id = ${userId}`;

// 修复后
const query = 'SELECT * FROM users WHERE id = ?';
const [rows] = await db.execute(query, [userId]);
```

## 下一步操作：

1. **运行扫描脚本**：执行 `run_sonarqube_scan.bat`
2. **收集截图**：保存SonarQube仪表盘截图
3. **分析结果**：识别2-3个最严重的安全问题
4. **生成报告**：按照模板格式化安全测试报告

## 注意事项：

- 确保SonarQube服务器在扫描前已启动
- 首次扫描可能需要较长时间（10-30分钟）
- 建议在测试环境中先进行扫描验证
- 保存好扫描报告和截图用于文档编写
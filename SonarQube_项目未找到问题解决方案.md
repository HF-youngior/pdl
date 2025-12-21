# SonarQube"项目未找到"问题解决方案

## 🔍 问题根本原因

经过完整诊断，发现"项目未找到"的主要原因是：

### 1. **API权限问题** ❌
- 当前使用的token `sqa_d49a6ec6411e46c30e59763979009aef34ecfd374773c7556eca2beb3741f9b6` 只有扫描权限
- 无法访问SonarQube的管理API来检查或创建项目
- SonarQube API返回401未授权错误

### 2. **配置文件冲突** ❌
- `sonar-project.properties`文件中存在重复的项目配置
- 有两套不同的projectKey和projectName设置

### 3. **项目未正确注册** ❌
- 扫描数据可能已上传，但项目在SonarQube中未正确注册
- 需要手动创建项目或使用管理员权限创建

## ✅ 已完成的修复

### 1. **修复配置文件**
- 统一项目配置为：
  ```
  sonar.projectKey=PDL-Enterprise-Management
  sonar.projectName=PDL企业管理系统
  ```
- 移除重复和冲突的配置项

### 2. **执行扫描**
- 成功执行安全扫描
- 生成了扫描报告文件

## 🚀 手动解决方案

### 方案1：Web界面手动创建项目

1. **访问SonarQube**
   ```
   http://localhost:9000
   ```

2. **登录系统**
   - 用户名: `admin`
   - 密码: `admin`
   - 首次登录需要修改密码

3. **手动创建项目**
   - 点击右上角 "+" 按钮
   - 选择 "Create new project"
   - 项目标识符: `PDL-Enterprise-Management`
   - 项目名称: `PDL企业管理系统`

4. **重新上传扫描数据**
   ```bash
   node f:\pdl\run_security_scan.js
   ```

### 方案2：使用管理员token

1. **生成管理员token**
   - 登录SonarQube (admin/admin)
   - 进入: My Account → Security
   - 生成新的token，命名为`admin_token`

2. **更新配置文件**
   ```properties
   sonar.login=新的管理员token
   ```

3. **重新执行扫描**
   ```bash
   node f:\pdl\run_security_scan.js
   ```

## 📊 当前状态

### ✅ 已完成
- SonarQube服务正常运行 (端口9000)
- 安全扫描执行成功
- 配置文件已修复
- 扫描报告已生成

### ⚠️ 需要手动操作
- 在Web界面创建项目
- 或获取管理员权限token

## 🎯 推荐操作步骤

### 立即执行：
1. 打开浏览器访问: `http://localhost:9000`
2. 使用admin/admin登录
3. 手动创建项目 `PDL-Enterprise-Management`
4. 重新运行扫描: `node f:\pdl\run_security_scan.js`

### 完成后访问：
```
http://localhost:9000/dashboard?id=PDL-Enterprise-Management
```

## 📁 相关文件

- `f:\pdl\sonar-project.properties` - 项目配置文件 (已修复)
- `f:\pdl\run_security_scan.js` - 安全扫描脚本
- `f:\pdl\security_scan_report.html` - 安全扫描报告
- `f:\pdl\sonar_security_scan_report.json` - SonarQube格式报告
- `f:\pdl\fix_sonarqube_project.js` - 问题诊断脚本

## 💡 快速访问脚本

创建了一个快速访问脚本，可以一键打开项目页面：

```bash
# Windows
start http://localhost:9000/dashboard?id=PDL-Enterprise-Management

# 或使用Node.js脚本
node f:\pdl\setup_sonarqube_access.js
```

---

**总结**: "项目未找到"主要是因为项目未在SonarQube中正确注册。通过手动创建项目或使用管理员权限token即可解决。
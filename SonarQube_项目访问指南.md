# SonarQube项目质量报告访问指南

## 🎯 直接访问方式

### ✅ 服务状态确认
- **SonarQube版本**: 25.12.0.117093  
- **服务状态**: 正常运行 (UP)
- **端口**: 9000
- **访问地址**: http://localhost:9000

### 🌐 直接访问链接

#### 1. 主页访问
```
http://localhost:9000
```

#### 2. 项目仪表板 (推荐)
```
http://localhost:9000/dashboard?id=PDL-Enterprise-Management
```

#### 3. 问题列表
```
http://localhost:9000/project/issues?id=PDL-Enterprise-Management
```

#### 4. 代码度量
```
http://localhost:9000/component_measures?id=PDL-Enterprise-Management
```

#### 5. 安全热点
```
http://localhost:9000/security_hotspots?id=PDL-Enterprise-Management
```

## 🔧 访问步骤

### 方法1: 通过主页访问
1. **打开浏览器**访问: http://localhost:9000
2. **登录账号**: admin / admin (首次登录需修改密码)
3. **搜索项目**: 在顶部搜索框输入 `PDL-Enterprise-Management`
4. **点击项目**: 查看完整的质量报告

### 方法2: 直接访问项目仪表板
1. **直接访问**: http://localhost:9000/dashboard?id=PDL-Enterprise-Management
2. **自动跳转登录**: 如未登录会跳转到登录页面
3. **登录后查看**: 直接显示项目质量报告

## 📊 项目信息

- **项目Key**: `PDL-Enterprise-Management`
- **项目名称**: `PDL企业管理系统`
- **源码路径**: `backend,lib`
- **扫描配置**: `sonar-project.properties`

## 🚨 如果项目未显示

### 可能原因
1. 项目尚未在SonarQube中注册
2. 代码扫描数据未上传
3. 项目Key不匹配
4. Token权限不足

### 解决方案

#### 方案1: 执行代码扫描
```bash
# 使用自定义扫描脚本
node f:\pdl\run_security_scan.js

# 或使用官方Scanner (需安装)
sonar-scanner
```

#### 方案2: 检查配置
确保 `sonar-project.properties` 文件中的配置正确:
```properties
sonar.projectKey=PDL-Enterprise-Management
sonar.projectName=PDL企业管理系统
sonar.host.url=http://localhost:9000
sonar.login=sqa_d49a6ec6411e46c30e59763979009aef34ecfd374773c7556eca2beb3741f9b6
```

#### 方案3: 手动创建项目
1. 访问 http://localhost:9000/projects/create
2. 输入项目Key: `PDL-Enterprise-Management`
3. 输入项目名称: `PDL企业管理系统`
4. 执行扫描上传数据

## 💡 快速访问脚本

运行以下脚本可自动打开项目页面:
```bash
node f:\pdl\setup_sonarqube_access.js
```

## 📱 移动端访问

SonarQube支持响应式设计，可通过手机浏览器访问:
- 手机访问: http://localhost:9000
- 项目仪表板: http://localhost:9000/dashboard?id=PDL-Enterprise-Management

## 🔒 安全注意事项

1. **修改默认密码**: 首次登录后立即修改admin密码
2. **配置权限**: 为不同用户配置适当的访问权限
3. **网络安全**: 生产环境建议配置HTTPS
4. **数据备份**: 定期备份SonarQube数据库

---

**更新时间**: 2025-01-25  
**SonarQube版本**: 25.12.0.117093  
**项目**: PDL企业管理系统
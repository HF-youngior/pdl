# 前端API连接问题解决方案

## 🔍 问题分析

根据您提供的截图和描述，主要问题有：

### 1. 登录失败问题
- **现象**: 输入正确的用户名密码显示"用户名或密码错误"
- **原因**: API连接失败，可能是URL配置问题

### 2. 数据加载失败问题
- **现象**: 网页端只能加载重要事项，用户和任务加载失败
- **原因**: API路径不匹配或数据库未正确初始化

### 3. 前端视图问题
- **现象**: 主页导图四大板块点不进去，任务获取失败
- **原因**: API连接失败导致数据无法加载

## ✅ 解决方案

### 第一步：检查数据库状态
```bash
cd backend
check_database.bat
```

### 第二步：重新初始化数据库
```bash
cd backend
fix_all_issues.bat
```

### 第三步：启动服务器
```bash
cd backend
start_enterprise_backend_correct.bat
```

### 第四步：测试API接口
```bash
cd backend
test_login.bat
```

## 🔧 已修复的问题

### 1. 数据库初始化问题
- 修复了服务器代码中部门名称不匹配的问题
- 确保数据库和服务器代码使用相同的部门ID

### 2. API路径兼容性
- 添加了兼容旧API的路由
- 确保前端可以正常调用API

### 3. 创建了调试工具
- `check_database.bat` - 检查数据库状态
- `test_login.bat` - 测试登录API
- `fix_all_issues.bat` - 一键修复所有问题

## 📋 测试步骤

### 1. 检查数据库
运行 `check_database.bat` 确认：
- 数据库连接正常
- 用户表有数据
- 任务表有数据
- 重要事项表有数据

### 2. 测试API
运行 `test_login.bat` 确认：
- 管理员登录正常
- 创始人登录正常
- 部门老总登录正常

### 3. 检查前端连接
- 确认Flutter应用中的API URL配置正确
- 确认网页端可以正常访问API

## 🌐 API接口测试

### 登录接口
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

### 获取用户列表
```bash
curl http://localhost:3000/api/users
```

### 获取任务列表
```bash
curl http://localhost:3000/api/tasks
```

### 获取重要事项
```bash
curl http://localhost:3000/api/important-items
```

## 🔍 故障排除

### 如果数据库检查失败
1. 确认MySQL服务正在运行
2. 确认密码 `Pyx_07091817` 正确
3. 重新运行 `init_enterprise_db_final.bat`

### 如果API测试失败
1. 确认服务器正在运行在端口3000
2. 确认防火墙没有阻止连接
3. 检查服务器控制台是否有错误信息

### 如果前端仍然无法连接
1. 检查Flutter应用中的API URL配置
2. 确认网络连接正常
3. 查看浏览器控制台或Flutter调试信息

## 📱 前端API配置

### Flutter应用
- 当前配置: `http://10.0.2.2:3000/api` (Android模拟器)
- 如果使用网页端: `http://localhost:3000/api`
- 如果使用真机: `http://[您的IP地址]:3000/api`

### 网页端
- 直接使用: `http://localhost:3000/api`

## 🚀 快速解决步骤

1. **运行问题修复脚本**：
   ```bash
   cd backend
   fix_all_issues.bat
   ```

2. **启动服务器**：
   ```bash
   start_enterprise_backend_correct.bat
   ```

3. **测试API**：
   ```bash
   test_login.bat
   ```

4. **访问网页端**：
   - 打开浏览器访问：http://localhost:3000/web_admin
   - 使用测试账户登录

5. **测试Flutter应用**：
   - 确认API URL配置正确
   - 重新运行Flutter应用

现在请按照上述步骤逐一排查和解决问题！

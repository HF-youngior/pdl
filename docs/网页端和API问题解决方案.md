# 网页端和API问题解决方案

## 🔍 问题分析

您遇到的问题主要有以下几个方面：

### 1. 登录问题
- **现象**: 输入正确的用户名密码显示"用户名和密码错误"
- **原因**: 可能是数据库没有正确初始化，或者密码加密不匹配

### 2. 网页端加载失败
- **现象**: "加载用户失败，加载任务失败"
- **原因**: API路径不匹配，新企业版服务器使用了不同的API路径

### 3. 前端视图加载失败
- **现象**: App前端视图无法加载数据
- **原因**: API接口路径变更，前端还在调用旧的API

## ✅ 解决方案

### 第一步：检查数据库状态
```bash
cd backend
fix_issues.bat
```

### 第二步：重新初始化数据库（如果需要）
```bash
init_enterprise_db_final.bat
```

### 第三步：启动服务器
```bash
start_enterprise_backend_correct.bat
```

### 第四步：测试API接口
```bash
test_api.bat
```

## 🔧 已修复的问题

### 1. 添加了兼容旧API的路由
- `/api/important-items` - 兼容旧的重要事项API
- `/api/personal-info/:userId` - 兼容旧的个人信息API
- `/api/logs` - 兼容旧的日志API

### 2. 创建了调试工具
- `debug_server.bat` - 调试模式启动服务器
- `test_api.bat` - 测试API接口
- `fix_issues.bat` - 问题诊断和修复

## 📋 测试账户信息

### 管理员
- **用户名**: admin
- **密码**: admin123

### 创始人
- **用户名**: founder1 / founder2
- **密码**: founder123

### 部门老总
- **人事总监**: hr_head / hr123
- **财务总监**: finance_head / finance123
- **宣传总监**: marketing_head / marketing123

### 团队长
- **人事组长**: hr_team1 / hrteam123
- **财务组长**: finance_team1 / financeteam123
- **宣传组长**: marketing_team1 / marketingteam123

### 员工
- **人事专员**: hr_emp1 / hremp123
- **财务专员**: finance_emp1 / financeemp123
- **宣传专员**: marketing_emp1 / marketingemp123

## 🌐 API接口列表

### 认证相关
- `POST /api/auth/login` - 用户登录
- `GET /api/user/profile` - 获取用户信息

### 数据获取
- `GET /api/users` - 获取用户列表
- `GET /api/tasks` - 获取任务列表
- `GET /api/important-items` - 获取重要事项（兼容旧API）
- `GET /api/company-important-items` - 获取公司重要事项（新API）
- `GET /api/personal-info/:userId` - 获取个人信息（兼容旧API）
- `GET /api/logs` - 获取系统日志（兼容旧API）

## 🚀 快速解决步骤

1. **运行问题诊断**：
   ```bash
   cd backend
   fix_issues.bat
   ```

2. **如果数据库为空，重新初始化**：
   ```bash
   init_enterprise_db_final.bat
   ```

3. **启动服务器**：
   ```bash
   start_enterprise_backend_correct.bat
   ```

4. **测试API**：
   ```bash
   test_api.bat
   ```

5. **访问网页端**：
   - 打开浏览器访问：http://localhost:3000/web_admin
   - 使用测试账户登录

## 🔍 故障排除

### 如果仍然无法登录
1. 检查数据库是否正确初始化
2. 确认用户名和密码是否正确
3. 查看服务器控制台是否有错误信息

### 如果网页端仍然加载失败
1. 检查服务器是否正常启动
2. 确认API接口是否正常响应
3. 查看浏览器控制台是否有错误信息

### 如果前端视图仍然无法加载
1. 检查API接口路径是否正确
2. 确认数据格式是否匹配
3. 查看网络请求是否成功

现在请按照上述步骤逐一排查和解决问题！

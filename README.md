# 企业管理系统

一个基于Flutter移动端和Web管理端的现代化企业管理系统，支持Android和iOS双平台，采用B/S架构进行运营管理。

## 项目架构

- **前端**: Flutter (Android/iOS)
- **后端**: Node.js + Express
- **数据库**: MySQL
- **Web管理端**: HTML + Bootstrap + JavaScript

## 功能特性

### 移动端 (Flutter)
- 用户登录（无注册功能，仅限管理员在Web端注册）
- 四个象限仪表板：
  - 左上：公司10大重要事项展示
  - 右上：公司10大任务派发
  - 左下：个人10大信息展示
  - 右下：日志展示
- 底部导航栏：导图、视图、日志、AI地图、我的
- 现代化UI设计，支持Material Design

### Web管理端
- 用户管理（注册、编辑、删除用户）
- 重要事项管理
- 任务管理
- 系统日志查看
- 数据统计仪表板

## 快速开始

### 环境要求
- Flutter SDK 3.9.2+
- Node.js 16+
- MySQL 8.0+
- Android Studio / Xcode (用于移动端开发)

### 1. 数据库设置

```sql
-- 创建数据库
CREATE DATABASE enterprise_management CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 导入数据库结构
mysql -u root -p enterprise_management < backend/database.sql
```

### 2. 后端设置

```bash
cd backend
npm install
cp env.example .env
# 编辑 .env 文件，配置数据库连接信息
npm start
```

### 3. Flutter移动端

```bash
# 安装依赖
flutter pub get

# 运行应用
flutter run
```

### 4. Web管理端

```bash
# 直接在浏览器中打开
open web_admin/index.html
```

## 默认账户

### 管理员账户
- 用户名: admin
- 密码: admin123

### 部门老总账户
- 用户名: manager
- 密码: manager123

### 普通员工账户
- 用户名: employee1
- 密码: employee123

## 项目结构

```
TestFlutterProject/
├── lib/                    # Flutter源代码
│   ├── models/            # 数据模型
│   ├── screens/           # 页面
│   ├── widgets/           # 组件
│   ├── services/          # API服务
│   └── utils/             # 工具类
├── backend/               # 后端API
│   ├── server.js          # 主服务器文件
│   ├── package.json       # 依赖配置
│   └── database.sql       # 数据库脚本
├── web_admin/             # Web管理端
│   ├── index.html         # 主页面
│   └── app.js             # 前端逻辑
└── README.md              # 项目说明
```

## API接口

### 认证接口
- `POST /api/auth/login` - 用户登录

### 数据接口
- `GET /api/important-items` - 获取重要事项
- `GET /api/tasks` - 获取任务列表
- `GET /api/personal-info/:userId` - 获取个人信息
- `GET /api/logs` - 获取系统日志
- `POST /api/logs` - 创建日志

## 开发说明

### 添加新功能
1. 在 `lib/models/` 中定义数据模型
2. 在 `lib/services/api_service.dart` 中添加API调用
3. 在 `lib/screens/` 中创建页面
4. 在 `backend/server.js` 中添加后端接口

### 数据库设计
- 用户表 (users): 存储用户基本信息
- 重要事项表 (important_items): 存储公司重要事项
- 任务表 (tasks): 存储任务分配信息
- 个人信息表 (personal_info): 存储个人相关信息
- 日志表 (logs): 存储系统操作日志

## 部署说明

### 生产环境部署
1. 配置生产环境数据库
2. 修改API基础URL
3. 配置HTTPS证书
4. 使用PM2管理Node.js进程

### 移动端发布
1. 配置签名证书
2. 修改应用包名和版本
3. 构建发布版本
4. 上传到应用商店

## 技术栈

- **前端框架**: Flutter 3.9.2
- **后端框架**: Node.js + Express
- **数据库**: MySQL 8.0
- **Web框架**: Bootstrap 5.3
- **认证**: JWT
- **密码加密**: bcryptjs

## 许可证

MIT License

## 贡献指南

1. Fork 项目
2. 创建功能分支
3. 提交更改
4. 推送到分支
5. 创建 Pull Request

## 联系方式

如有问题或建议，请通过以下方式联系：
- 邮箱: your-email@example.com
- 项目地址: https://github.com/your-username/enterprise-management
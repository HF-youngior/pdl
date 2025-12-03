# 字符编码问题修复说明

## 🐛 问题描述

在 Flutter 应用的月视图中，所有中文文字都显示为问号（`?????`）。

## 🔍 问题原因

MySQL 数据库连接的字符集配置不正确：
1. Node.js 连接数据库时没有正确设置字符集
2. 数据库表可能使用了错误的字符集

## ✅ 解决方案

### 1. 修改 Node.js 数据库连接配置

在 `server_enterprise.js` 中：

```javascript
// 数据库连接配置
const dbConfig = {
  host: process.env.DB_HOST || 'rm-2ze22f1xm8vvw4m44to.mysql.rds.aliyuncs.com',
  user: process.env.DB_USER || 'pdl',
  password: process.env.DB_PASSWORD || 'Pdl123456',
  database: process.env.DB_NAME || 'enterprise_management',
  port: process.env.DB_PORT || 3306,
  charset: 'utf8mb4',  // 添加字符集配置
  multipleStatements: true
};
```

### 2. 在连接时设置字符集

在 `initDatabase()` 函数中添加：

```javascript
async function initDatabase() {
  try {
    db = await mysql.createConnection(dbConfig);
    
    // 设置连接字符集（关键！）
    await db.query("SET NAMES 'utf8mb4'");
    await db.query("SET CHARACTER SET utf8mb4");
    await db.query("SET character_set_connection=utf8mb4");
    
    console.log('数据库连接成功');
    
    // 创建表
    await createTables();
  } catch (error) {
    console.error('数据库连接失败:', error);
    process.exit(1);
  }
}
```

### 3. 转换数据库和表的字符集

执行以下 SQL 命令：

```sql
-- 转换数据库字符集
ALTER DATABASE enterprise_management 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

-- 转换 personal_logs 表
ALTER TABLE personal_logs 
CONVERT TO CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

-- 转换 tasks 表
ALTER TABLE tasks 
CONVERT TO CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;
```

或者在 PowerShell 中执行：

```powershell
# 转换数据库
mysql -h rm-2ze22f1xm8vvw4m44to.mysql.rds.aliyuncs.com -u pdl -pPdl123456 enterprise_management -e "ALTER DATABASE enterprise_management CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# 转换表
mysql -h rm-2ze22f1xm8vvw4m44to.mysql.rds.aliyuncs.com -u pdl -pPdl123456 enterprise_management -e "ALTER TABLE personal_logs CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

mysql -h rm-2ze22f1xm8vvw4m44to.mysql.rds.aliyuncs.com -u pdl -pPdl123456 enterprise_management -e "ALTER TABLE tasks CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

## 📋 验证修复

### 方法1: 使用 Node.js 脚本验证

```javascript
const mysql = require('mysql2/promise');

async function test() {
  const db = await mysql.createConnection({
    host: 'rm-2ze22f1xm8vvw4m44to.mysql.rds.aliyuncs.com',
    user: 'pdl',
    password: 'Pdl123456',
    database: 'enterprise_management',
    charset: 'utf8mb4'
  });
  
  await db.query("SET NAMES 'utf8mb4'");
  await db.query("SET CHARACTER SET utf8mb4");
  await db.query("SET character_set_connection=utf8mb4");
  
  const [rows] = await db.query(
    'SELECT title FROM personal_logs LIMIT 3'
  );
  
  console.log('查询结果:', rows);
  await db.end();
}

test().catch(console.error);
```

如果能正确显示中文，说明修复成功！

### 方法2: 检查 MySQL 字符集

```bash
mysql -h rm-2ze22f1xm8vvw4m44to.mysql.rds.aliyuncs.com -u pdl -pPdl123456 -e "SHOW VARIABLES LIKE 'character_set%';"
```

期望看到：
- `character_set_database`: `utf8mb4`
- `character_set_server`: `utf8mb4`

### 方法3: 在 Flutter 应用中验证

1. 重启 Node.js 服务器
2. 重新启动 Flutter 应用
3. 登录 `hr_head` 用户
4. 进入月视图
5. 点击任意有数据的日期
6. 查看任务和日志的标题和内容

如果显示正确的中文而不是问号，说明问题已解决！

## 🎯 重启服务器

修复后必须重启服务器才能生效：

```powershell
# 停止 Node.js 进程
Get-Process | Where-Object {$_.ProcessName -eq 'node'} | Stop-Process -Force

# 等待1秒
Start-Sleep -Seconds 1

# 重新启动
cd D:\pdl\backend
node server_enterprise.js
```

## 💡 关键点

1. **必须设置 `charset: 'utf8mb4'`**: 在数据库连接配置中
2. **必须执行 SET NAMES 命令**: 在每次连接建立后
3. **必须转换表的字符集**: 确保数据库和表都使用 utf8mb4
4. **必须重启服务器**: 修改配置后才能生效

## 📱 Flutter 端不需要修改

Flutter 应用端不需要任何修改，因为：
- HTTP API 传输使用 UTF-8 编码
- JSON 格式天然支持 Unicode
- 问题完全出在服务器端的数据库连接

## ✅ 修复状态

- [x] 修改 `server_enterprise.js` 数据库配置
- [x] 添加字符集设置命令
- [x] 转换数据库字符集
- [x] 转换 `personal_logs` 表字符集
- [x] 转换 `tasks` 表字符集
- [x] 验证修复成功
- [x] 重启服务器

## 🎉 期望结果

修复后，在 Flutter 应用的月视图中：
- ✅ 任务标题正确显示中文（如"绩效考核方案"）
- ✅ 任务描述正确显示中文
- ✅ 日志标题正确显示中文（如"薪酬体系优化"）
- ✅ 日志内容正确显示中文
- ✅ 所有中文字符都能正常显示

不再出现问号（`?????`）！

---

**修复时间**: 2025-10-22  
**影响范围**: 所有中文文本显示  
**状态**: ✅ 已修复  
**维护者**: PDL Team

























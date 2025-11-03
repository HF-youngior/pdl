# Backend 使用指南

## 快速开始

### 第一次使用项目

**完整初始化（推荐）：**
```batch
cd backend
init_all_data.bat
```

这会创建一个包含所有测试数据的完整数据库。

### 日常开发

**启动后端服务：**
```batch
cd backend
start_enterprise_backend_correct.bat
```

## 批处理文件说明

### 🚀 初始化脚本

| 文件名 | 用途 | 使用场景 |
|--------|------|----------|
| `init_all_data.bat` | **完整初始化** | 首次搭建、完整数据 |
| `init_enterprise_db_latest.bat` | 基础初始化 | 快速测试、基础数据 |
| `init_ai_module_complete.bat` | AI模块初始化 | 单独初始化AI功能 |

**推荐：** 新用户直接使用 `init_all_data.bat`

### 📦 数据增强脚本

| 文件名 | 用途 | 使用场景 |
|--------|------|----------|
| `add_more_test_data.bat` | **数据增强菜单** | 添加更多测试数据 |
| `load_ai_test_data.bat` | 加载AI测试数据 | 单独测试AI功能 |
| `load_mbti_data.bat` | 加载MBTI数据 | 单独测试MBTI |

**注意：** `load_more_test_data.bat`, `load_hr_monthly_tasks.bat`, `load_hr_rich_logs.bat` 已被整合到 `add_more_test_data.bat`

### 🔧 更新脚本

| 文件名 | 用途 | 使用场景 |
|--------|------|----------|
| `update_mbti_data.bat` | 更新MBTI数据 | MBTI类型调整 |
| `update_all_hr_descriptions.bat` | 更新HR任务描述 | 补充任务描述 |
| `create_ai_module_tables.bat` | 创建AI表 | 单独创建AI表 |

### 🧪 测试脚本

| 文件名 | 用途 |
|--------|------|
| `test_ai_personality.bat` | AI性格分析测试 |
| `run_mbti_tests.bat` | MBTI功能测试 |
| `start_enterprise_backend_correct.bat` | **启动后端服务** |

## 工作流程

### 场景1：新团队成员加入

```batch
# 1. 完整初始化数据库
cd backend
init_all_data.bat

# 2. 启动后端
start_enterprise_backend_correct.bat

# 3. 测试API（可选）
cd ..
测试API连接.bat
```

### 场景2：需要更多测试数据

```batch
cd backend
add_more_test_data.bat
# 选择需要的数据类型
```

### 场景3：更新MBTI数据

```batch
cd backend
update_mbti_data.bat
```

### 场景4：重置数据库

```batch
cd backend
init_all_data.bat
```

**⚠️ 警告：这会删除所有现有数据！**

## 已废弃的文件

以下文件已被整合，保留为备份：

- `load_more_test_data.old.bat`
- `load_hr_monthly_tasks.old.bat`
- `load_hr_rich_logs.old.bat`

如需使用这些功能，请使用 `add_more_test_data.bat`

## 数据库配置

默认配置：
- Host: localhost
- Port: 3306
- User: root
- Password: Pyx_07091817
- Database: enterprise_management

如需修改，请编辑对应 bat 文件中的配置参数。

## 常见问题

### Q: 初始化失败？

A: 检查：
1. MySQL服务是否启动
2. 数据库连接信息是否正确
3. 是否有足够的磁盘空间

### Q: 密码连接失败？

A: 确认密码是 `Pyx_07091817`，或修改 bat 文件中的密码配置

### Q: 需要单独初始化某个模块？

A: 使用对应的初始化脚本：
- AI模块：`init_ai_module_complete.bat`
- MBTI模块：`load_mbti_data.bat`

### Q: 想要清理数据从头开始？

A: 运行 `init_all_data.bat` 会删除并重建整个数据库

## 文件组织结构

```
backend/
├── init_all_data.bat              ← 推荐：完整初始化
├── init_enterprise_db_latest.bat  ← 基础初始化
├── add_more_test_data.bat         ← 数据增强菜单
├── start_enterprise_backend_correct.bat  ← 启动服务
├── update_mbti_data.bat           ← 更新MBTI
├── update_all_hr_descriptions.bat ← 更新描述
├── test_ai_personality.bat        ← AI测试
├── run_mbti_tests.bat             ← MBTI测试
└── *.sql                          ← SQL数据文件
```

## 下一步

初始化完成后：
1. 启动后端服务
2. 测试API连接
3. 启动Flutter应用
4. 开始开发！


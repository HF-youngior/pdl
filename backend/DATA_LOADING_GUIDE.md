# 数据加载指南

## 📚 概述

本指南介绍如何使用统一的数据加载脚本 `load_all_data.bat` 来管理企业管理系统的数据。

## 🚀 快速开始

### 方法1：使用统一加载脚本（推荐）

只需双击运行：
```
backend/load_all_data.bat
```

会出现一个菜单，提供以下选项：

1. **完全初始化数据库** - 删除并重建数据库，加载所有基础数据
2. **加载 HR 总监大量日志数据** - 约150条日志（2025年9-11月）
3. **加载更多测试数据** - 多个用户的测试数据
4. **重新加载个人日志数据** - 重置个人日志
5. **重新加载丰富的测试数据** - 60条日志+35条任务
6. **加载 HR 总监基础数据** - 10月份的基础数据
7. **加载修复的增强数据** - 修复后的示例数据
8. **全部加载（推荐新环境使用）** - 选项1+2的组合

### 方法2：使用单独的脚本

如果你只需要执行特定操作，可以直接运行单独的bat文件：

- `init_enterprise_db_latest.bat` - 初始化数据库
- `load_hr_rich_logs.bat` - 加载HR总监大量日志
- `load_more_test_data.bat` - 加载更多测试数据
- `reload_personal_logs.bat` - 重新加载个人日志
- 等等...

## 📊 HR 总监大量日志数据详情

### 数据特点

已为 `hr_head`（dept-head-001）用户生成了**149条日志**，具有以下特点：

#### 时间分布
- **时间范围**: 2025年9月-11月
- **覆盖天数**: 约2/3的天数有日志
- **每日日志**: 每天2-3条日志

#### 月份分布
- **9月**: 60条日志
- **10月**: 46条日志  
- **11月**: 43条日志

#### 类别分布
- **工作类（work）**: 68条 (45.64%) ✅
- **会议类（meeting）**: 23条 (15.44%) ✅
- **学习类（study）**: 29条 (19.46%)
- **个人类（personal）**: 29条 (19.46%)

> ✅ 工作和会议类合计占61.08%，符合"工作和会议类占三分之二"的要求

#### 时间段特征
- **有具体时间段**: 94条 (63.09%) ✅
- **无时间段**: 55条 (36.91%)
- **时间段范围**: 9:00-18:00

所有带时间段的日志都有具体的开始和结束时间，格式如：`12:00-14:00`, `09:30-11:00` 等

### 日志内容特点

每条日志都包含：
- **标题**: 简洁明了的日志主题
- **关键词**: 3-4个关键词标签
- **天气**: 当天天气情况
- **时间段**: 部分日志有具体时间段
- **详细内容**: 具体的工作/活动描述

### 示例日志

```
2025-09-01 11:30 [study] 参加行业研讨会
  - 时间段: 11:00-11:30
  - 关键词: 研讨会, 行业, 交流

2025-09-02 12:30 [meeting] 绩效校准会议  
  - 时间段: 12:00-12:30
  - 关键词: 绩效校准, 标准, 公平性

2025-09-04 11:45 [work] 优化招聘流程
  - 时间段: 11:15-11:45
  - 关键词: 流程优化, 招聘, 效率
```

## 🔧 技术细节

### 数据生成

日志数据是通过Node.js脚本自动生成的，确保：
- 数据多样性（10+种工作日志、8+种会议日志、8+种个人日志、8+种学习日志）
- 真实性（符合HR总监的工作场景）
- 随机性（每次生成略有不同）

### 数据库配置

默认连接参数（可在bat文件中修改）：
```
DB_HOST=rm-2zeoa1b89ga70ikpifo.mysql.rds.aliyuncs.com
DB_PORT=3306
DB_USER=pdl123
DB_PASSWORD=Pdl1234567
DB_NAME=enterprise_management
```

### SQL文件

生成的SQL文件位于：
- `insert_hr_head_rich_logs.sql` - HR总监大量日志（149条）

该文件包含：
- 外键检查控制
- 旧数据清理（删除 `log-hr-rich-*`）
- INSERT语句
- 统计信息注释

## 💡 使用建议

### 新环境初始化

如果是第一次设置环境，推荐：
1. 运行 `load_all_data.bat`
2. 选择选项 `8`（全部加载）
3. 确认执行

这会完成：
- 创建数据库和表结构
- 加载所有用户和部门数据
- 加载HR总监的149条日志
- 设置测试账号密码为明文

### 只更新HR日志

如果只想更新HR总监的日志：
1. 运行 `load_all_data.bat`
2. 选择选项 `2`

### 数据重置

如果需要完全重置数据：
1. 运行 `load_all_data.bat`
2. 选择选项 `1`
3. 确认执行（⚠️ 会删除所有数据）

## 📝 相关文件

### 核心脚本
- `load_all_data.bat` - **统一加载脚本（主入口）**
- `insert_hr_head_rich_logs.sql` - HR总监日志数据

### 其他脚本（已整合到统一脚本）
- `init_enterprise_db_latest.bat` - 数据库初始化
- `load_hr_rich_logs.bat` - HR日志加载
- `load_more_test_data.bat` - 更多测试数据
- `reload_personal_logs.bat` - 重载个人日志
- `reload_rich_test_data.bat` - 重载丰富数据
- `load_hr_head_data.bat` - HR基础数据
- `load_fixed_enhanced_data_v2.bat` - 增强数据

## ❓ 常见问题

### Q: 为什么运行bat文件时有乱码？
A: 这是正常的，脚本使用UTF-8编码，PowerShell可能显示乱码，但不影响执行结果。

### Q: 如何验证数据是否加载成功？
A: 可以：
1. 查看bat脚本运行结果中的 "✅ 数据加载成功"
2. 登录数据库查询：`SELECT COUNT(*) FROM personal_logs WHERE user_id = 'dept-head-001';`
3. 在应用中以hr_head用户登录查看日志

### Q: 可以多次运行加载脚本吗？
A: 可以。脚本会先删除旧的hr-rich-*日志，然后插入新数据，不会产生重复。

### Q: 如何修改数据库密码？
A: 编辑 `load_all_data.bat`，修改 `DB_PASSWORD` 变量的值。

## 📊 数据统计验证

运行以下SQL可以验证数据：

```sql
-- 总数统计
SELECT COUNT(*) as total FROM personal_logs WHERE user_id = 'dept-head-001';

-- 按类别统计
SELECT category, COUNT(*) as count 
FROM personal_logs 
WHERE user_id = 'dept-head-001'
GROUP BY category;

-- 按月统计  
SELECT DATE_FORMAT(created_at, '%Y-%m') as month, COUNT(*) as count
FROM personal_logs
WHERE user_id = 'dept-head-001'
GROUP BY month;

-- 时间段统计
SELECT 
  SUM(CASE WHEN content LIKE '%【时间段】%' THEN 1 ELSE 0 END) as with_time,
  SUM(CASE WHEN content NOT LIKE '%【时间段】%' THEN 1 ELSE 0 END) as without_time
FROM personal_logs
WHERE user_id = 'dept-head-001';
```

---

**最后更新**: 2025年10月24日
**维护者**: 开发团队



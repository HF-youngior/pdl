# 测试数据说明

## 概述

为了充分测试月视图功能，我们创建了丰富的测试数据，包含9个用户在2025年9-11月期间的日志和任务记录。

## 数据统计

- **总日志数**: 62条
- **总任务数**: 37个
- **时间跨度**: 2025年9月-11月（3个月）
- **用户数量**: 9个（不同角色：创始人、部门负责人、团队负责人、普通员工）

### 按月统计

| 月份 | 日志数 | 任务数 | 合计 |
|------|--------|--------|------|
| 2025-09 | 21 | 10 | 31 |
| 2025-10 | 22 | 11 | 33 |
| 2025-11 | 19 | 16 | 35 |
| **合计** | **62** | **37** | **99** |

## 测试用户列表

### 1. founder-001 (Zhang Founder) - 创始人
- **部门**: dept-001
- **数据量**: 8条日志, 5个任务
- **特点**: 高优先级战略任务，包含进行中和待处理任务

### 2. founder-002 (Li Founder) - 创始人
- **部门**: dept-001
- **数据量**: 7条日志, 3个任务
- **特点**: 技术相关任务，包含进行中任务

### 3. dept-head-001 (Wang HR Director) - HR部门负责人
- **部门**: dept-001
- **数据量**: 6条日志, 4个任务
- **特点**: HR管理类任务，全部完成

### 4. dept-head-002 (Zhao Finance Director) - 财务部门负责人
- **部门**: dept-002
- **数据量**: 6条日志, 3个任务
- **特点**: 财务管理任务，包含进行中的年度报告

### 5. team-leader-001 (Liu HR Team Lead) - HR团队负责人
- **部门**: dept-001
- **数据量**: 6条日志, 4个任务
- **特点**: 招聘和团队管理任务

### 6. team-leader-002 (Sun HR Team Lead) - HR团队负责人
- **部门**: dept-001
- **数据量**: 6条日志, 4个任务
- **特点**: 财务流程优化任务

### 7. employee-001 (Chen HR Specialist) - HR专员
- **部门**: dept-001
- **数据量**: 9条日志, 6个任务
- **特点**: 招聘执行任务，包含生活类日志

### 8. employee-002 (Chu HR Specialist) - HR专员
- **部门**: dept-001
- **数据量**: 7条日志, 4个任务
- **特点**: 员工服务任务，包含体检和团建

### 9. employee-003 (Wei HR Specialist) - HR专员
- **部门**: dept-001
- **数据量**: 7条日志, 4个任务
- **特点**: 财务操作任务，包含生活类日志

## 数据特点

### 日志分类
- **工作类 (work)**: 约80%
- **生活类 (life)**: 约20%

### 任务状态分布
- **已完成 (completed)**: ~70%
- **进行中 (in_progress)**: ~20%
- **待处理 (pending)**: ~10%

### 任务优先级分布
- **P0 (最高)**: ~40%
- **P1 (高)**: ~35%
- **P2 (中)**: ~15%
- **P3 (低)**: ~10%

## 导入方法

### 方法1: 命令行导入（推荐）

**Windows**:
```bash
cd D:\pdl\backend
mysql -h localhost -u root -p23301144 enterprise_management < create_rich_test_data.sql
```

**Linux/Mac**:
```bash
cd backend
mysql -h localhost -u root -p enterprise_management < create_rich_test_data.sql
```

### 方法2: MySQL Workbench导入
1. 打开MySQL Workbench
2. 连接到 `enterprise_management` 数据库
3. File -> Run SQL Script
4. 选择 `create_rich_test_data.sql`
5. 点击运行

### 方法3: phpMyAdmin导入
1. 登录 phpMyAdmin
2. 选择 `enterprise_management` 数据库
3. 点击"导入"标签
4. 选择 `create_rich_test_data.sql`
5. 点击"执行"

## 验证导入

导入完成后，执行以下SQL验证：

```sql
-- 查看日志总数
SELECT COUNT(*) FROM personal_logs;  
-- 应该返回: 62

-- 查看任务总数
SELECT COUNT(*) FROM tasks WHERE id LIKE 'test-task-%';  
-- 应该返回: 37

-- 按月统计日志
SELECT 
    DATE_FORMAT(created_at, '%Y-%m') AS month,
    COUNT(*) AS log_count
FROM personal_logs
GROUP BY DATE_FORMAT(created_at, '%Y-%m')
ORDER BY month;

-- 按月统计任务
SELECT 
    DATE_FORMAT(created_at, '%Y-%m') AS month,
    COUNT(*) AS task_count
FROM tasks
WHERE id LIKE 'test-task-%'
GROUP BY DATE_FORMAT(created_at, '%Y-%m')
ORDER BY month;
```

## 测试API

### 无需认证的测试API

**端点**: `GET /api/month-view/:userId/:year/:month`

**示例请求**:

```bash
# 查看 founder-001 在 2025年9月 的数据
curl http://localhost:8080/api/month-view/founder-001/2025/9

# 查看 employee-001 在 2025年10月 的数据
curl http://localhost:8080/api/month-view/employee-001/2025/10

# 查看 dept-head-001 在 2025年11月 的数据
curl http://localhost:8080/api/month-view/dept-head-001/2025/11
```

**响应示例**:

```json
{
  "month": "2025-09",
  "userId": "founder-001",
  "logs": [
    {
      "id": "log-f001-sep1",
      "title": "公司战略规划讨论",
      "content": "与管理层讨论了下一季度的战略方向，重点关注市场扩展和产品创新。",
      "category": "work",
      "quadrant": null,
      "isCompleted": false,
      "date": "2025-09-05",
      "createdAt": "2025-09-05T01:00:00.000Z"
    }
  ],
  "tasks": [
    {
      "id": "test-task-f001-sep1",
      "title": "完成Q3总结报告",
      "description": "整理Q3季度的各项数据和成果。",
      "status": "completed",
      "priority": "p0",
      "color": "#4CAF50",
      "startTime": null,
      "endTime": null,
      "deadline": "2025-09-30T10:00:00.000Z",
      "isAllDay": false,
      "assigneeName": "Zhang Founder",
      "date": "2025-09-30"
    }
  ],
  "statistics": {
    "totalTasks": 1,
    "completedTasks": 1,
    "inProgressTasks": 0,
    "pendingTasks": 0,
    "totalLogs": 3,
    "completedLogs": 2
  }
}
```

## 推荐测试场景

### 场景1: 数据量适中的月份（9月）
- 用户: `founder-001`
- 特点: 3条日志, 1个已完成任务
- 测试目标: 基本的月视图显示

### 场景2: 数据量较大的月份（10月）
- 用户: `employee-001`
- 特点: 3条日志, 2个任务, 包含生活类日志
- 测试目标: 混合类型数据的显示

### 场景3: 包含进行中任务的月份（11月）
- 用户: `founder-001`
- 特点: 2条日志, 1个进行中任务, 1个待处理任务
- 测试目标: 不同状态任务的显示

### 场景4: 团队负责人视角（11月）
- 用户: `team-leader-001`
- 特点: 2条日志, 2个任务（1个已完成，1个进行中）
- 测试目标: 中层管理视角

### 场景5: 普通员工视角（10月）
- 用户: `employee-002`
- 特点: 2条日志, 1个任务, 包含体检类任务
- 测试目标: 基层员工视角

## 清理测试数据

如果需要清理测试数据，执行：

```sql
-- 只清理测试数据，保留原有数据
DELETE FROM personal_logs WHERE id LIKE 'log-%';
DELETE FROM tasks WHERE id LIKE 'test-task-%';
```

或者重新运行 `create_rich_test_data.sql`（脚本开头包含清理语句）。

## 注意事项

1. **数据库编码**: 确保MySQL使用UTF-8编码，否则中文可能显示乱码
2. **时区设置**: 测试数据使用UTC时间，请注意时区转换
3. **用户ID**: 测试数据使用的用户ID必须在users表中存在
4. **部门ID**: 任务数据使用的部门ID必须在departments表中存在
5. **ID格式**: 
   - 日志ID格式: `log-{用户缩写}-{月份缩写}{序号}`
   - 任务ID格式: `test-task-{用户缩写}-{月份缩写}{序号}`

## 相关文件

- `create_rich_test_data.sql`: 测试数据SQL脚本
- `docs/月视图功能测试说明.md`: 完整的功能测试文档
- `backend/server_enterprise.js`: 包含月视图API实现

## 技术支持

如有问题，请检查：
1. MySQL服务是否运行
2. 数据库连接配置是否正确
3. 用户权限是否足够
4. 数据库编码设置
5. 服务器日志输出

---

**最后更新**: 2025-10-22
**版本**: 1.0
**维护者**: PDL Team










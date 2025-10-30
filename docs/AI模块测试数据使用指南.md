# AI模块测试数据使用指南

## 概述

本指南介绍如何使用AI模块的测试数据生成脚本，为所有可登录用户创建完整的MBTI、性格分析和词云分析数据。

## 文件说明

### 核心脚本文件

1. **create_ai_module_tables.bat** - AI模块表创建脚本
   - 创建 `wordcloud_analysis` 表
   - 创建 `personality_analysis` 表
   - 设置索引和外键约束

2. **load_ai_test_data.bat** - AI测试数据加载脚本
   - 为所有用户生成MBTI数据
   - 生成性格分析数据
   - 生成词云分析数据

3. **init_ai_module_complete.bat** - 完整初始化脚本
   - 一键完成所有AI模块初始化
   - 包含数据验证和完整性检查

4. **load_mbti_data.bat** - 更新的MBTI数据脚本
   - 集成AI模块指引
   - 提供完整的操作流程

## 使用方法

### 方法1：一键初始化（推荐）

```bash
cd backend
init_ai_module_complete.bat
```

### 方法2：分步执行

```bash
cd backend

# 步骤1：创建AI模块表
create_ai_module_tables.bat

# 步骤2：加载测试数据
load_ai_test_data.bat
```

### 方法3：仅MBTI数据

```bash
cd backend
load_mbti_data.bat
```

## 生成的数据内容

### 用户覆盖范围

- **管理员**：1人 (admin-001) - ENFP
- **创始人**：1人 (founder-001) - INTJ
- **部门总监**：3人 (人事、财务、宣传) - ISFJ, ISTJ, ENFJ
- **团队长**：3人 (人事、财务、宣传团队长) - ENTJ, ISTJ, ESFJ
- **员工**：3人 (人事、财务、宣传专员) - ENFP, ISTJ, ENFP

### 数据类型

#### 1. MBTI记录数据
- 基于职位的合理MBTI类型分配
- 完整的测试分数和性格特质
- AI分析结果和工作建议
- 个人改进建议

#### 2. 性格分析数据
- 五大人格特质评分
- 个性化工作建议
- 性格图表数据
- 职业发展建议

#### 3. 词云分析数据
- 基于职位特点的关键词
- 词频统计和权重
- 工作日志分析结果

## 数据特点

### MBTI类型分配策略

| 职位类型 | MBTI类型 | 特点 |
|---------|---------|------|
| 管理员 | ENFP | 外向、创新、灵活 |
| 创始人 | INTJ | 内向、直觉、思考、判断 |
| 人事总监 | ISFJ | 内向、感觉、情感、判断 |
| 财务总监 | ISTJ | 内向、感觉、思考、判断 |
| 宣传总监 | ENFJ | 外向、直觉、情感、判断 |
| 团队长 | 混合 | ENTJ, ISTJ, ESFJ |
| 员工 | 混合 | ENFP, ISTJ, ENFP |

### AI分析结果特点

- **个性化**：基于职位和角色的定制化分析
- **真实性**：符合实际工作场景的数据
- **完整性**：包含所有必要的分析维度
- **一致性**：MBTI类型与分析结果匹配

## 验证数据

### 检查表创建

```sql
SHOW TABLES LIKE '%analysis%';
```

### 检查数据量

```sql
SELECT 
    'wordcloud_analysis' as table_name, 
    COUNT(*) as record_count 
FROM wordcloud_analysis
UNION ALL
SELECT 
    'personality_analysis' as table_name, 
    COUNT(*) as record_count 
FROM personality_analysis
UNION ALL
SELECT 
    'mbti_records' as table_name, 
    COUNT(*) as record_count 
FROM mbti_records;
```

### 检查用户数据

```sql
SELECT 
    u.name,
    u.position,
    pa.mbti_type,
    pa.description
FROM personality_analysis pa
JOIN users u ON pa.user_id = u.id
ORDER BY u.name;
```

## 测试账户

| 用户名 | 密码 | 角色 | MBTI类型 |
|--------|------|------|----------|
| admin | admin123 | 系统管理员 | ENFP |
| founder1 | founder123 | 创始人 | INTJ |
| hr_head | hr123 | 人事总监 | ISFJ |
| finance_head | finance123 | 财务总监 | ISTJ |
| marketing_head | marketing123 | 宣传总监 | ENFJ |

## 故障排除

### 常见问题

1. **数据库连接失败**
   - 检查MySQL服务是否启动
   - 验证数据库连接参数
   - 确认用户权限

2. **表创建失败**
   - 检查数据库是否存在
   - 验证用户权限
   - 查看错误日志

3. **数据插入失败**
   - 检查表结构是否正确
   - 验证JSON格式
   - 查看外键约束

### 错误处理

脚本包含完整的错误检查：
- 每个步骤都有错误码检查
- 失败时会显示详细错误信息
- 提供暂停功能便于调试

## 扩展使用

### 添加新用户数据

1. 在 `load_ai_test_data.bat` 中添加新用户
2. 选择合适的MBTI类型
3. 生成对应的分析数据
4. 重新运行脚本

### 修改数据内容

1. 编辑SQL生成部分
2. 调整MBTI类型分配
3. 修改分析结果内容
4. 重新生成数据

## 注意事项

1. **数据备份**：运行前建议备份现有数据
2. **权限检查**：确保数据库用户有足够权限
3. **字符编码**：使用UTF8MB4字符集
4. **外键约束**：确保用户表数据完整

## 下一步操作

1. **启动服务器**：`npm start`
2. **打开应用**：启动Flutter应用
3. **测试功能**：进入AI地图模块
4. **验证数据**：检查分析结果
5. **配置API**：添加DeepSeek API Key（可选）

---

**注意**：本测试数据仅用于开发和演示目的，生产环境请使用真实数据。

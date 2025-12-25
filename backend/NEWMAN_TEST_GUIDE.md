# Newman测试脚本使用指南

## 概述

本指南将介绍如何使用Newman（Postman的命令行工具）运行MBTI和AI模块的测试脚本，并生成HTML测试报告。

## 前置条件

1. 确保已安装Node.js和npm
2. 确保PDL后端服务器正在运行（端口8080）
3. 已获取有效的hr_head角色Token

## 安装Newman

```bash
npm install -g newman
npm install -g newman-reporter-html
```

## 测试文件说明

- `mbti_ai_postman_collection.json`: Postman测试集合，包含所有MBTI和AI模块的测试用例
- `mbti_ai_postman_environment.json`: Postman环境变量配置文件
- `NEWMAN_TEST_GUIDE.md`: 本使用指南

## 运行测试步骤

### 步骤1：获取认证Token

使用hr_head角色登录系统，获取有效的Bearer Token。

### 步骤2：设置环境变量

编辑 `mbti_ai_postman_environment.json` 文件，将 `token` 字段的值替换为实际获取的Token：

```json
{
  "key": "token",
  "value": "YOUR_ACTUAL_TOKEN_HERE",
  "type": "secret",
  "enabled": true
}
```

### 步骤3：运行测试

在命令行中执行以下命令：

```bash
# 进入backend目录
cd f:\pdl\backend

# 运行测试并生成HTML报告
newman run mbti_ai_postman_collection.json -e mbti_ai_postman_environment.json -r cli,html --reporter-html-export report.html
```

### 步骤4：查看报告

测试完成后，会在当前目录生成 `report.html` 文件。使用浏览器打开该文件即可查看详细的测试报告。

## 测试用例说明

### MBTI模块测试用例

1. **MBTI-001 创建MBTI测评记录**
   - 测试创建MBTI测评记录功能
   - 验证返回的记录ID和基本信息

2. **MBTI-002 获取MBTI测评记录列表**
   - 测试获取所有MBTI测评记录
   - 验证分页和记录数量

3. **MBTI-003 获取最近一次MBTI测评记录**
   - 测试获取最新的MBTI测评记录

4. **MBTI-004 获取单条MBTI测评记录**
   - 测试根据ID获取特定MBTI测评记录

5. **MBTI-005 更新MBTI测评记录**
   - 测试更新已有MBTI测评记录

6. **MBTI-006 删除MBTI测评记录**
   - 测试删除MBTI测评记录

7. **MBTI-007 获取MBTI统计信息**
   - 测试获取MBTI测评统计数据

### AI分析模块测试用例

1. **AI-001 对日志进行AI分析**
   - 测试日志文本的AI分析功能
   - 验证关键词和词频提取

2. **AI-002 分析今日任务/日志**
   - 测试分析今日的任务和日志

3. **AI-003 保存词云分析结果**
   - 测试保存词云分析结果
   - 验证保存的记录信息

4. **AI-004 获取词云历史记录**
   - 测试获取所有词云分析历史

5. **AI-005 发起人格分析请求**
   - 测试根据日志内容进行人格分析

6. **AI-006 获取人格分析历史记录**
   - 测试获取所有人格分析历史

## 自定义测试

如果需要修改测试用例，可以：

1. 在Postman中导入 `mbti_ai_postman_collection.json` 文件
2. 进行所需的修改
3. 导出修改后的集合并替换原文件

## 常见问题

### 1. 测试失败 - 认证错误

**原因**：Token无效或已过期

**解决方法**：重新获取有效的Token并更新环境变量文件

### 2. 测试失败 - 服务器未响应

**原因**：PDL后端服务器未运行或端口错误

**解决方法**：确保服务器正在运行，并检查环境变量中的 `base_url` 配置

### 3. 测试失败 - 权限不足

**原因**：使用的Token没有足够的权限

**解决方法**：确保使用的是hr_head角色的Token

## 报告解读

HTML报告包含以下信息：

- 测试概述（通过/失败的测试用例数量）
- 每个测试用例的详细结果
- 请求和响应的详细信息
- 测试耗时统计
- 失败的测试用例原因分析

报告可以帮助团队快速定位问题并进行修复。
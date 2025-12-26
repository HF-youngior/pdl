# AI地图模块功能说明

## 概述
AI地图模块现已升级，包含词云分析、性格分析和历史记录三大功能板块。

## 功能特性

### 1. 词云分析
- **一键分析并保存**：分析今日日志并自动保存结果
- **增强视觉效果**：词云图具有大小重要程度和颜色区别
- **历史记录**：可以查看不同日期的词云分析结果

### 2. 性格分析
- **DeepSeek API集成**：使用DeepSeek AI进行性格分析
- **MBTI分析**：结合日志信息和MBTI类型进行分析
- **工作建议**：基于性格分析提供个性化工作建议
- **图表展示**：雷达图和条形图展示性格特质

### 3. 历史记录
- **词云历史**：查看所有保存的词云分析
- **性格历史**：查看所有性格分析报告
- **详情查看**：点击历史记录查看完整分析结果

## 技术实现

### 前端组件
- `EnhancedWordCloud`: 增强版词云组件，支持颜色渐变和大小区分
- `PersonalityChart`: 性格分析图表组件，包含雷达图和条形图
- `AiMapScreen`: 主界面，使用TabView组织不同功能

### 数据模型
- `WordCloudAnalysis`: 词云分析结果模型
- `PersonalityAnalysis`: 性格分析结果模型

### API服务
- `AiService`: 扩展的AI服务，支持词云保存和性格分析
- DeepSeek API集成：支持外部AI服务调用

## 使用方法

### 词云分析
1. 点击"一键分析并保存今日日志"按钮
2. 系统自动分析今日日志并生成词云
3. 分析结果自动保存到历史记录
4. 在"历史记录"标签页查看所有词云分析

### 性格分析
1. 点击"AI性格分析（DeepSeek）"按钮
2. 系统调用DeepSeek API进行性格分析
3. 查看MBTI类型、性格特质和工作建议
4. 分析结果保存到历史记录

### 查看历史
1. 切换到"历史记录"标签页
2. 选择"词云历史"或"性格历史"
3. 点击任意记录查看详细分析结果

## 测试数据
当API不可用时，系统会自动使用测试数据：
- 词云测试数据：包含工作、学习、项目等关键词
- 性格测试数据：ENFP类型，包含完整的性格分析结果

## 后端配置

### DeepSeek API配置
```javascript
// 环境变量配置
DEEPSEEK_API_KEY=your-deepseek-api-key

// API端点
const DEEPSEEK_API_URL = 'https://api.deepseek.com/v1/chat/completions';
```

### 数据库表结构
```sql
-- 词云分析表
CREATE TABLE wordcloud_analysis (
  id VARCHAR(255) PRIMARY KEY,
  user_id VARCHAR(255) NOT NULL,
  analysis_date DATETIME NOT NULL,
  keywords JSON,
  word_frequencies JSON,
  description TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 性格分析表
CREATE TABLE personality_analysis (
  id VARCHAR(255) PRIMARY KEY,
  user_id VARCHAR(255) NOT NULL,
  analysis_date DATETIME NOT NULL,
  personality_traits JSON,
  mbti_type VARCHAR(10),
  work_suggestions JSON,
  personality_chart JSON,
  description TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

## 注意事项
1. 确保后端API正常运行
2. DeepSeek API需要有效的API密钥
3. 测试数据仅在API不可用时使用
4. 所有分析结果都会保存到历史记录中

## 未来扩展
- 支持更多AI服务提供商
- 增加更多性格分析维度
- 支持自定义词云样式
- 添加数据导出功能

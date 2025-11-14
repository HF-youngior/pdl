# AI地图提示词实现详解

## 概述

AI地图功能通过分析用户的工作日志，结合MBTI性格类型，生成个性化的职业发展建议。整个流程分为三个关键部分：

1. **前端日志数据格式化** - 将日志数据转换为结构化文本
2. **后端AI提示词设计** - 构建详细的提示词指导AI分析
3. **前端结果展示** - 将AI返回的结构化数据渲染到UI

---

## 关键文件清单

### 1. 后端提示词核心
- **文件**: `backend/server_enterprise.js`
- **函数**: `analyzePersonalityWithDeepSeek()` (第4229行)
- **API路由**: `/api/ai/personality-analysis` (第4086行)

### 2. 前端日志格式化
- **文件**: `lib/services/ai_service.dart`
- **函数**: `_formatLogsForAnalysis()` (第195行)
- **函数**: `getUserLogsText()` (第161行)

### 3. 前端UI展示
- **文件**: `lib/screens/ai_map_screen.dart`
- **函数**: `_buildWorkSuggestionsWidget()` (第411行)

---

## 详细代码解析

### 一、前端日志格式化 (`lib/services/ai_service.dart`)

#### 1.1 `getUserLogsText()` - 获取用户日志

```dart
static Future<String> getUserLogsText({int days = 30}) async {
  // 1. 从API获取所有日志
  final response = await httpClient.get(
    Uri.parse('${ApiService.baseUrl}/personal-logs'),
    headers: ApiService.getAuthHeaders(),
  );
  
  // 2. 筛选最近N天的日志（默认30天）
  final now = DateTime.now();
  final recentLogs = logs.where((log) {
    final logDate = DateTime.parse(log['created_at']);
    return now.difference(logDate).inDays <= days;
  }).toList();
  
  // 3. 格式化日志为结构化文本
  return _formatLogsForAnalysis(recentLogs);
}
```

**作用**: 
- 从后端获取用户的所有个人日志
- 筛选最近30天的日志（可配置）
- 调用格式化函数转换为文本

#### 1.2 `_formatLogsForAnalysis()` - 格式化日志为分析文本

```dart
static String _formatLogsForAnalysis(List<dynamic> logs) {
  final logEntries = logs.map((log) {
    // 提取日志字段
    final title = log['title'] ?? '';
    final content = log['content'] ?? '';
    final category = log['category'] ?? '';
    final quadrant = log['quadrant'] ?? '';
    final createdAt = log['created_at'] ?? '';
    
    // 处理关联任务信息
    final taskUpdates = log['taskUpdates'] as List<dynamic>?;
    String taskInfo = '';
    if (taskUpdates != null && taskUpdates.isNotEmpty) {
      final taskNames = taskUpdates.map((task) {
        final taskName = task['taskName'] ?? '';
        final progress = task['progress_percentage'] ?? 0;
        return '$taskName(进度: $progress%)';
      }).join('、');
      taskInfo = '关联任务: $taskNames';
    }
    
    // 格式化日期
    final date = DateTime.parse(createdAt);
    final dateStr = '${date.year}年${date.month}月${date.day}日';
    
    // 转换四象限优先级为中文
    final quadrantMap = {
      'important_urgent': '重要且紧急',
      'important_not_urgent': '重要不紧急',
      'not_important_urgent': '不重要但紧急',
      'not_important_not_urgent': '不重要不紧急',
    };
    
    // 构建日志条目
    final parts = <String>[];
    parts.add('【$dateStr】$title');
    if (category.isNotEmpty) parts.add('分类: $category');
    if (quadrant.isNotEmpty) parts.add('优先级: ${quadrantMap[quadrant]}');
    if (taskInfo.isNotEmpty) parts.add(taskInfo);
    if (content.isNotEmpty) parts.add('内容: $content');
    
    return parts.join('\n');
  }).join('\n\n');
  
  return logEntries;
}
```

**输出格式示例**:
```
【2025年10月15日】完成月度绩效考核
分类: 人事管理
优先级: 重要且紧急
关联任务: 员工绩效评估(进度: 85%)
内容: 完成了本月的员工绩效考核工作...

【2025年10月14日】团队会议讨论
分类: 团队协作
优先级: 重要不紧急
内容: 今天与团队讨论了新项目的规划...
```

**关键点**:
- 包含日期、标题、分类、优先级、关联任务、内容等完整信息
- 使用中文格式化，便于AI理解
- 每条日志之间用空行分隔，结构清晰

---

### 二、后端提示词设计 (`backend/server_enterprise.js`)

#### 2.1 `analyzePersonalityWithDeepSeek()` - 核心分析函数

**位置**: 第4229-4419行

**函数结构**:
```javascript
async function analyzePersonalityWithDeepSeek(logText, mbtiType, retryCount = 0) {
  // 1. 日志长度处理（限制在8000字符以内）
  let processedLogText = logText;
  if (logText.length > MAX_LOG_LENGTH) {
    // 保留开头和结尾，中间截取
    const startPart = logText.substring(0, 2000);
    const endPart = logText.substring(logText.length - (MAX_LOG_LENGTH - 2000));
    processedLogText = startPart + '\n\n[...中间部分已省略...]\n\n' + endPart;
  }
  
  // 2. 构建提示词
  const prompt = `...`; // 详见下方
  
  // 3. 调用DeepSeek API
  const response = await axios.post(DEEPSEEK_API_URL, {
    model: 'deepseek-chat',
    messages: [
      {
        role: 'system',
        content: '你是一位资深的职业发展顾问和性格分析师...'
      },
      {
        role: 'user',
        content: prompt
      }
    ],
    temperature: 0.7,
    max_tokens: 4000  // 支持更详细的分析
  });
  
  // 4. 解析JSON响应
  const jsonMatch = content.match(/\{[\s\S]*\}/);
  const parsedData = JSON.parse(jsonMatch[0]);
  
  return parsedData;
}
```

#### 2.2 提示词核心内容解析

**提示词分为四个部分**:

##### 第一部分：角色定位
```
你是一位资深的职业发展顾问和性格分析师。请基于用户的工作日志进行深入分析，结合MBTI性格类型，给出个性化的职业发展建议。
```

##### 第二部分：三步分析任务

**第一步：深入分析每篇日志的有效信息**
```
请仔细阅读每篇日志，提取以下关键信息：
1. **工作内容**：具体做了哪些工作？涉及哪些领域和行业？
2. **技能体现**：从日志中可以看出哪些技能（如沟通、管理、分析、创新、执行等）？
3. **工作偏好**：更倾向于什么类型的工作（独立工作/团队协作、创新/执行、战略/细节等）？
4. **工作挑战**：遇到了哪些困难或挑战？如何应对的？
5. **成就与成长**：取得了哪些成果？有哪些成长和进步？
6. **工作模式**：工作节奏、优先级管理方式、时间分配特点
```

**第二步：结合MBTI类型进行综合分析**
```
${mbtiType ? 
  `已知MBTI类型：${mbtiType}。请结合该MBTI类型的典型特征，分析日志中的行为模式是否与MBTI类型一致，并识别出独特的工作风格。` 
  : 
  '如果无法确定MBTI类型，请基于日志内容推断可能的MBTI类型。'
}
```

**第三步：给出具体的职业建议**
```
基于日志分析和MBTI类型，提供：
1. **当前工作适配度**：当前工作内容与性格类型的匹配程度
2. **适合的职业方向**：具体列出3-5个最适合的职业方向，并说明原因
3. **职业发展路径**：短期（1-2年）和长期（3-5年）的职业发展建议
4. **能力提升建议**：需要重点发展的技能和能力
5. **工作环境建议**：最适合的工作环境、团队文化、管理风格
```

##### 第三部分：日志内容输入
```
## 日志内容

${processedLogText}

${mbtiType ? `\n## 已知MBTI类型\n${mbtiType}\n` : ''}
```

##### 第四部分：输出格式要求

**JSON结构**:
```json
{
  "personalityTraits": {
    "外向性": 0.8,
    "宜人性": 0.6,
    "尽责性": 0.9,
    "神经质": 0.3,
    "开放性": 0.7
  },
  "mbtiType": "ESTJ",
  "workSuggestions": {
    "日志分析摘要": "基于日志分析，总结用户的工作特点、技能优势和兴趣方向（100-200字）",
    "当前工作适配度": 0.85,
    "适合职业": [
      {
        "职业名称": "人力资源总监",
        "匹配原因": "结合日志和MBTI分析...",
        "发展前景": "该职业的发展前景..."
      }
    ],
    "职业发展路径": {
      "短期目标": "1-2年的职业发展建议（具体、可执行）",
      "长期目标": "3-5年的职业发展建议（结合性格特点和职业兴趣）"
    },
    "能力提升建议": [
      "需要重点发展的技能1（结合日志中的不足）",
      "需要重点发展的技能2",
      "需要重点发展的技能3"
    ],
    "工作环境建议": {
      "理想工作环境": "描述最适合的工作环境特点",
      "团队文化": "适合的团队文化和管理风格",
      "工作方式": "推荐的工作方式和节奏"
    },
    "发展建议": "综合性的职业发展建议（200-300字，结合日志分析和MBTI类型）"
  },
  "logAnalysis": {
    "工作领域": "从日志中识别的主要工作领域",
    "核心技能": ["技能1", "技能2", "技能3"],
    "工作偏好": "偏好的工作类型和方式",
    "成长轨迹": "从日志中观察到的成长和进步"
  }
}
```

**关键约束条件**:
```
请确保：
1. 所有建议都基于日志中的具体内容，不要泛泛而谈
2. 结合MBTI类型特征，但不要完全依赖MBTI，要结合实际工作表现
3. 给出具体、可执行的建议，避免空泛的描述
4. 数值评分要合理，基于日志内容进行客观评估
```

---

### 三、前端UI展示 (`lib/screens/ai_map_screen.dart`)

#### 3.1 `_buildWorkSuggestionsWidget()` - 构建工作建议Widget

**位置**: 第411-573行

**功能**: 将AI返回的JSON数据转换为Flutter Widget，展示在UI上

**关键代码结构**:
```dart
List<Widget> _buildWorkSuggestionsWidget(Map<String, dynamic> suggestions) {
  final widgets = <Widget>[];
  
  // 1. 日志分析摘要
  if (suggestions.containsKey('日志分析摘要')) {
    widgets.add(_buildSuggestionSection(
      '📊 日志分析摘要',
      suggestions['日志分析摘要'].toString(),
      icon: Icons.analytics_outlined,
    ));
  }
  
  // 2. 当前工作适配度
  if (suggestions.containsKey('当前工作适配度')) {
    final score = suggestions['当前工作适配度'];
    final scoreValue = score is num ? score.toDouble() : (double.tryParse(score.toString()) ?? 0.0);
    widgets.add(_buildSuggestionSection(
      '🎯 当前工作适配度',
      '${(scoreValue * 100).toStringAsFixed(0)}%',
      subtitle: _getAdaptabilityDescription(scoreValue),
      icon: Icons.gps_fixed,
    ));
  }
  
  // 3. 适合职业（支持新格式：对象数组）
  if (suggestions.containsKey('适合职业')) {
    final careers = suggestions['适合职业'];
    if (careers is List) {
      widgets.add(_buildSuggestionSection(
        '💼 适合职业',
        null,
        icon: Icons.work_outline,
        children: careers.map((career) {
          if (career is Map) {
            return _buildCareerCard(career);  // 新格式：职业卡片
          } else {
            return Padding(...);  // 旧格式兼容
          }
        }).toList(),
      ));
    }
  }
  
  // 4. 职业发展路径
  if (suggestions.containsKey('职业发展路径')) {
    final path = suggestions['职业发展路径'];
    if (path is Map) {
      widgets.add(_buildSuggestionSection(
        '🚀 职业发展路径',
        null,
        icon: Icons.trending_up,
        children: [
          if (path.containsKey('短期目标'))
            _buildPathItem('短期目标（1-2年）', path['短期目标'].toString()),
          if (path.containsKey('长期目标'))
            _buildPathItem('长期目标（3-5年）', path['长期目标'].toString()),
        ],
      ));
    }
  }
  
  // 5. 能力提升建议
  if (suggestions.containsKey('能力提升建议')) {
    final skills = suggestions['能力提升建议'];
    if (skills is List) {
      widgets.add(_buildSuggestionSection(
        '📈 能力提升建议',
        null,
        icon: Icons.school_outlined,
        children: skills.map((skill) => Padding(...)).toList(),
      ));
    }
  }
  
  // 6. 工作环境建议
  if (suggestions.containsKey('工作环境建议')) {
    final env = suggestions['工作环境建议'];
    if (env is Map) {
      widgets.add(_buildSuggestionSection(
        '🏢 工作环境建议',
        null,
        icon: Icons.business_outlined,
        children: [
          if (env.containsKey('理想工作环境'))
            _buildEnvItem('理想工作环境', env['理想工作环境'].toString()),
          if (env.containsKey('团队文化'))
            _buildEnvItem('团队文化', env['团队文化'].toString()),
          if (env.containsKey('工作方式'))
            _buildEnvItem('工作方式', env['工作方式'].toString()),
        ],
      ));
    }
  }
  
  // 7. 发展建议
  if (suggestions.containsKey('发展建议')) {
    widgets.add(_buildSuggestionSection(
      '💡 综合发展建议',
      suggestions['发展建议'].toString(),
      icon: Icons.lightbulb_outline,
    ));
  }
  
  return widgets;
}
```

**显示效果**:
- 📊 日志分析摘要
- 🎯 当前工作适配度（百分比 + 描述）
- 💼 适合职业（职业卡片，包含匹配原因和发展前景）
- 🚀 职业发展路径（短期/长期目标）
- 📈 能力提升建议（技能列表）
- 🏢 工作环境建议（理想环境/团队文化/工作方式）
- 💡 综合发展建议

---

## 数据流程

```
用户日志数据
    ↓
[前端] getUserLogsText() 
    ↓ 获取最近30天日志
[前端] _formatLogsForAnalysis()
    ↓ 格式化为结构化文本
[前端] analyzePersonalityWithDeepSeek()
    ↓ POST /api/ai/personality-analysis
[后端] analyzePersonalityWithDeepSeek()
    ↓ 构建提示词 + 调用DeepSeek API
DeepSeek API
    ↓ 返回JSON分析结果
[后端] 解析JSON并返回
    ↓
[前端] PersonalityAnalysis.fromJson()
    ↓
[前端] _buildWorkSuggestionsWidget()
    ↓ 渲染UI组件
用户界面显示
```

---

## 提示词设计要点

### 1. 结构化分析流程
- **三步分析法**：日志分析 → MBTI结合 → 职业建议
- 确保AI按步骤深入分析，避免浅层结论

### 2. 具体化要求
- 要求"基于日志中的具体内容"，避免泛泛而谈
- 要求"给出具体、可执行的建议"
- 要求"数值评分要合理，基于日志内容进行客观评估"

### 3. 输出格式约束
- 严格的JSON格式要求
- 包含所有必要字段
- 支持新旧格式兼容

### 4. 日志信息完整性
- 前端格式化时包含：日期、标题、分类、优先级、关联任务、内容
- 为AI提供足够的信息进行深度分析

---

## 技术细节

### API配置
- **模型**: `deepseek-chat`
- **Temperature**: 0.7（平衡创造性和准确性）
- **Max Tokens**: 4000（支持详细分析）
- **超时时间**: 60秒
- **重试机制**: 最多3次，延迟2秒

### 错误处理
- 网络错误自动重试
- JSON解析失败时使用默认数据
- 保留原始AI分析文本供调试

---

## 优化建议

1. **日志筛选增强**: 可按分类、优先级筛选要分析的日志
2. **分析历史对比**: 对比不同时期的分析结果，观察职业发展变化
3. **个性化提示词**: 根据不同行业、职位定制提示词
4. **多语言支持**: 如果日志包含多语言内容，优化提示词支持多语言分析


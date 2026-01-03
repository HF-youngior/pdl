# ViewScreen 界面空白问题分析

## 问题描述
月任务视图下方区域为空，日历显示正常但任务列表未显示。

## 可能原因分析

### 1. 时间范围筛选问题 ⚠️ **最可能**
**现象：** 日历显示正常，但任务列表为空

**原因：**
- 当前日期是 2025年1月
- 筛选逻辑使用 `_currentDate` (2025-01) 作为基准
- 任务数据主要是 2025年10月的数据
- `_filterByMonth` 方法只显示 2025年1月的任务

**证据：**
```dart:lib/screens/view_screen.dart:148-151
List<Task> _filterByMonth(List<Task> tasks, DateTime date) {
  final startOfMonth = DateTime(date.year, date.month, 1);
  final endOfMonth = DateTime(date.year, date.month + 1, 0, 23, 59, 59);
  // 只筛选当月任务
}
```

**解决方案：**
- 选项1：修改 `_currentDate` 初始值为 2025年10月
- 选项2：扩大筛选范围，显示近三个月任务
- 选项3：允许用户手动切换到10月查看数据

### 2. 任务数据加载问题
**现象：** 前端无法从后端获取数据

**检查点：**
- 后端服务是否正常运行
- API 请求是否成功
- 网络连接是否正常
- 认证 token 是否有效

**检查方法：**
```dart
print('Total tasks: ${_allTasks.length}');
print('Filtered tasks: ${_filteredTasks.length}');
print('Current date: $_currentDate');
```

### 3. 筛选条件过严
**现象：** 状态筛选或时间筛选导致所有任务被过滤

**检查点：**
- `_selectedFilter` 的值
- `_selectedView` 的值
- 筛选逻辑是否正确

### 4. UI 渲染问题
**现象：** 数据存在但界面不显示

**检查点：**
- `Expanded` widget 是否正确嵌套
- `Column` 的 `mainAxisSize` 设置
- ListView 是否正确构建

## 诊断步骤

### 步骤1：添加调试日志
在 `_buildTaskList()` 方法中添加：
```dart
print('🔍 Debug Info:');
print('  _allTasks.length: ${_allTasks.length}');
print('  _filteredTasks.length: ${_filteredTasks.length}');
print('  _currentDate: $_currentDate');
print('  _selectedView: $_selectedView');
print('  _selectedFilter: $_selectedFilter');
```

### 步骤2：检查后端数据
```sql
SELECT start_time, title FROM tasks LIMIT 10;
```

### 步骤3：测试筛选逻辑
将筛选逻辑临时注释，看是否有数据显示：
```dart
// 临时测试
return _allTasks; // 显示所有任务
```

## 推荐解决方案

### 方案1：调整初始日期（最快）
```dart
DateTime _currentDate = DateTime(2025, 10, 1); // 改为10月
```

### 方案2：扩大筛选范围
```dart
List<Task> _filterByMonth(List<Task> tasks, DateTime date) {
  // 显示前后一个月的任务
  final startOfRange = DateTime(date.year, date.month - 1, 1);
  final endOfRange = DateTime(date.year, date.month + 2, 0);
  return tasks.where((task) {
    return task.startTime.isAfter(startOfRange) &&
           task.startTime.isBefore(endOfRange);
  }).toList();
}
```

### 方案3：添加默认数据
如果确实没有当月数据，显示友好提示：
```dart
Widget _buildTaskList() {
  if (_filteredTasks.isEmpty) {
    return _buildEmptyState(); // 显示"暂无任务"提示
  }
  // ...
}
```

## 结论

**最可能的原因：** 当前日期 (2025年1月) 与任务数据 (2025年10月) 不匹配，导致所有任务被时间筛选过滤掉。

**推荐操作：** 先添加调试日志确认数据加载情况，然后调整初始日期或筛选范围。


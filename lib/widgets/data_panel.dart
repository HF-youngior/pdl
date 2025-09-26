import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/statistics_service.dart';

class DataPanel extends StatefulWidget {
  final String userId;
  final VoidCallback? onRefresh;

  const DataPanel({super.key, required this.userId, this.onRefresh});

  @override
  State<DataPanel> createState() => DataPanelState();
}

class DataPanelState extends State<DataPanel> {
  TaskStatistics? _todayStats;
  TaskStatistics? _last7DaysStats;
  bool _isLoading = true;
  String _selectedPeriod = 'today'; // 'today' or 'last7days'

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final todayStats = await StatisticsService.getTodayStatistics(widget.userId);
      final last7DaysStats = await StatisticsService.getLast7DaysStatistics(widget.userId);
      
      setState(() {
        _todayStats = todayStats;
        _last7DaysStats = last7DaysStats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('加载统计数据失败: $e');
    }
  }

  Future<void> refreshData() async {
    await _loadStatistics();
    if (widget.onRefresh != null) {
      widget.onRefresh!();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    final currentStats = _selectedPeriod == 'today' ? _todayStats : _last7DaysStats;
    if (currentStats == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text('暂无数据'),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题和日期选择
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedPeriod == 'today' ? '今日数据' : '近7日数据',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: refreshData,
                      tooltip: '刷新数据',
                    ),
                    _buildPeriodButton('今日', 'today'),
                    const SizedBox(width: 8),
                    _buildPeriodButton('近7日', 'last7days'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 统计卡片
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '完成计划数',
                    '${currentStats.completedTasks}/${currentStats.totalTasks}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    '完成率',
                    '${currentStats.completionRate.toStringAsFixed(1)}%',
                    Icons.trending_up,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 优先级分布标题
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '完成计划优先级分布',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.share, size: 20),
                  onPressed: () {
                    // 分享功能
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 圆环图
            Center(
              child: SizedBox(
                height: 120,
                width: 120,
                child: _buildDonutChart(currentStats),
              ),
            ),
            const SizedBox(height: 16),

            // 图例
            _buildLegend(currentStats),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String label, String period) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonutChart(TaskStatistics stats) {
    final distribution = stats.priorityDistribution;
    final total = distribution.values.fold(0, (sum, count) => sum + count);

    if (total == 0) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[100],
        ),
        child: const Center(
          child: Text(
            '暂无数据',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 35,
        sections: [
          _buildPieSection(
            'important_urgent',
            distribution['important_urgent']!,
            total,
            const Color(0xFFE53E3E), // 红色 - 重要且紧急
          ),
          _buildPieSection(
            'important_not_urgent',
            distribution['important_not_urgent']!,
            total,
            const Color(0xFF3182CE), // 蓝色 - 重要不紧急
          ),
          _buildPieSection(
            'not_important_urgent',
            distribution['not_important_urgent']!,
            total,
            const Color(0xFFD69E2E), // 黄色 - 紧急不重要
          ),
          _buildPieSection(
            'not_important_not_urgent',
            distribution['not_important_not_urgent']!,
            total,
            const Color(0xFF38A169), // 绿色 - 不重要不紧急
          ),
        ],
      ),
    );
  }

  PieChartSectionData _buildPieSection(
    String key,
    int value,
    int total,
    Color color,
  ) {
    if (value == 0) {
      return PieChartSectionData(
        value: 0,
        color: Colors.transparent,
        showTitle: false,
        radius: 0,
      );
    }

    return PieChartSectionData(
      color: color,
      value: value.toDouble(),
      title: '',
      radius: 45,
      titleStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildLegend(TaskStatistics stats) {
    final distribution = stats.priorityDistribution;
    final legendItems = [
      {
        'label': '重要且紧急',
        'count': distribution['important_urgent']!,
        'color': const Color(0xFFE53E3E),
      },
      {
        'label': '重要不紧急',
        'count': distribution['important_not_urgent']!,
        'color': const Color(0xFF3182CE),
      },
      {
        'label': '紧急不重要',
        'count': distribution['not_important_urgent']!,
        'color': const Color(0xFFD69E2E),
      },
      {
        'label': '不重要不紧急',
        'count': distribution['not_important_not_urgent']!,
        'color': const Color(0xFF38A169),
      },
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: legendItems.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: item['color'] as Color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${item['label']}: ${item['count']}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

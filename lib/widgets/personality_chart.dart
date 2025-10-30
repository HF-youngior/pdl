import 'package:flutter/material.dart';
import 'dart:math' as math;

class PersonalityChart extends StatelessWidget {
  final Map<String, dynamic> personalityData;
  final String mbtiType;

  const PersonalityChart({
    super.key,
    required this.personalityData,
    required this.mbtiType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // MBTI 类型显示
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[400]!, Colors.purple[400]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Text(
                'MBTI 性格类型',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                mbtiType,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        // 性格特质雷达图
        _buildRadarChart(),
        const SizedBox(height: 20),
        
        // 性格维度条形图
        _buildBarChart(),
      ],
    );
  }

  Widget _buildRadarChart() {
    final traits = personalityData['traits'] as Map<String, dynamic>? ?? {};
    final traitNames = traits.keys.toList();
    final traitValues = traits.values.map((v) => (v as num).toDouble()).toList();
    
    if (traitNames.isEmpty) {
      return _buildEmptyRadarChart();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '性格特质雷达图',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: CustomPaint(
              painter: RadarChartPainter(traitNames, traitValues),
              size: const Size(200, 200),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRadarChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '性格特质雷达图',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  '暂无分析数据',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '请先完成性格分析',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    final dimensions = personalityData['dimensions'] as Map<String, dynamic>? ?? {};
    final dimensionNames = dimensions.keys.toList();
    final dimensionValues = dimensions.values.map((v) => (v as num).toDouble()).toList();
    
    if (dimensionNames.isEmpty) {
      return _buildEmptyBarChart();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '性格维度分析',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...dimensionNames.asMap().entries.map((entry) {
            final index = entry.key;
            final name = entry.value;
            final value = dimensionValues[index];
            return _buildBarItem(name, value);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildEmptyBarChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '性格维度分析',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.bar_chart_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  '暂无分析数据',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '请先完成性格分析',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarItem(String name, double value) {
    final colors = [
      Colors.blue[400]!,
      Colors.green[400]!,
      Colors.orange[400]!,
      Colors.purple[400]!,
      Colors.red[400]!,
    ];
    final colorIndex = name.hashCode % colors.length;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text('${(value * 100).round()}%'),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.grey[200],
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: colors[colorIndex],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RadarChartPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;
  final double maxValue;

  RadarChartPainter(this.labels, this.values, {this.maxValue = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;
    
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    
    final strokePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // 绘制网格
    for (int i = 1; i <= 5; i++) {
      final gridRadius = radius * i / 5;
      canvas.drawCircle(center, gridRadius, Paint()..color = Colors.grey.withOpacity(0.2));
    }

    // 绘制轴线
    for (int i = 0; i < labels.length; i++) {
      final angle = 2 * math.pi * i / labels.length - math.pi / 2;
      final endPoint = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(center, endPoint, Paint()..color = Colors.grey.withOpacity(0.3));
    }

    // 绘制数据点
    final points = <Offset>[];
    for (int i = 0; i < labels.length; i++) {
      final angle = 2 * math.pi * i / labels.length - math.pi / 2;
      final value = values[i] / maxValue;
      final point = Offset(
        center.dx + radius * value * math.cos(angle),
        center.dy + radius * value * math.sin(angle),
      );
      points.add(point);
    }

    // 绘制多边形
    if (points.isNotEmpty) {
      final path = Path();
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      path.close();
      
      canvas.drawPath(path, paint);
      canvas.drawPath(path, strokePaint);
    }

    // 绘制标签
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < labels.length; i++) {
      final angle = 2 * math.pi * i / labels.length - math.pi / 2;
      final labelPoint = Offset(
        center.dx + (radius + 15) * math.cos(angle),
        center.dy + (radius + 15) * math.sin(angle),
      );
      
      textPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(fontSize: 12, color: Colors.black87),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          labelPoint.dx - textPainter.width / 2,
          labelPoint.dy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

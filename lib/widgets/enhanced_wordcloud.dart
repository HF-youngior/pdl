import 'package:flutter/material.dart';
import 'dart:math' as math;

class EnhancedWordCloud extends StatelessWidget {
  final List<Map<String, dynamic>> words;
  final double? width;
  final double? height;
  final Color? backgroundColor;

  const EnhancedWordCloud({
    super.key,
    required this.words,
    this.width,
    this.height,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return Container(
        width: width,
        height: height ?? 200,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Center(
          child: Text(
            '暂无词云数据',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final maxCount = words.first['count'] is num ? words.first['count'] : 1;
    final minCount = words.last['count'] is num ? words.last['count'] : 1;
    
    // 颜色渐变方案
    final colors = [
      const Color(0xFF1E3A8A), // 深蓝
      const Color(0xFF3B82F6), // 蓝色
      const Color(0xFF60A5FA), // 浅蓝
      const Color(0xFF10B981), // 绿色
      const Color(0xFFF59E0B), // 橙色
      const Color(0xFFEF4444), // 红色
    ];

    return Container(
      width: width,
      height: height ?? 300,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: words.map((w) {
                final count = (w['count'] is num) ? (w['count'] as num).toDouble() : 1.0;
                final normalizedCount = (count - minCount) / (maxCount - minCount);
                
                // 根据频率计算字体大小
                final fontSize = 12.0 + normalizedCount * 24.0;
                
                // 根据频率选择颜色
                final colorIndex = (normalizedCount * (colors.length - 1)).round();
                final color = colors[math.min(colorIndex, colors.length - 1)];
                
                // 根据频率计算透明度
                final opacity = 0.6 + normalizedCount * 0.4;
                
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(opacity * 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: color.withOpacity(opacity * 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    w['word'].toString(),
                    style: TextStyle(
                      fontSize: fontSize,
                      color: color.withOpacity(opacity),
                      fontWeight: normalizedCount > 0.7 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}

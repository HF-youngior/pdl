import 'package:flutter/material.dart';
import 'dart:math' as math;

class EnhancedWordCloud extends StatefulWidget {
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
  State<EnhancedWordCloud> createState() => _EnhancedWordCloudState();
}

class _EnhancedWordCloudState extends State<EnhancedWordCloud>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final List<AnimationController> _wordControllers = [];
  final List<Animation<double>> _wordAnimations = [];

  @override
  void initState() {
    super.initState();
    
    // 主动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // 为每个词创建独立的动画控制器
    for (int i = 0; i < widget.words.length; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 300 + (i * 50)),
      );
      
      final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.elasticOut,
        ),
      );
      
      _wordControllers.add(controller);
      _wordAnimations.add(animation);
    }
    
    // 启动动画
    _animationController.forward();
    
    // 延迟启动每个词的动画，创造波浪效果
    for (int i = 0; i < _wordControllers.length; i++) {
      Future.delayed(Duration(milliseconds: 100 + (i * 30)), () {
        if (mounted) {
          _wordControllers[i].forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (var controller in _wordControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.words.isEmpty) {
      return Container(
        width: widget.width,
        height: widget.height ?? 200,
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? Colors.grey[50],
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

    // 优先使用importance，如果没有则使用count
    final sortedWords = List<Map<String, dynamic>>.from(widget.words);
    
    // 提取所有importance和count值，用于计算范围
    final importanceValues = sortedWords.map((w) {
      if (w['importance'] is num) {
        return (w['importance'] as num).toDouble();
      } else if (w['count'] is num) {
        return (w['count'] as num).toDouble();
      }
      return 0.0;
    }).toList();
    
    // 计算最大值和最小值
    double maxImportance = importanceValues.isNotEmpty 
        ? importanceValues.reduce((a, b) => a > b ? a : b)
        : 1.0;
    double minImportance = importanceValues.isNotEmpty
        ? importanceValues.reduce((a, b) => a < b ? a : b)
        : 0.0;
    
    // 如果所有值都相同，设置一个小的差异范围，确保有视觉区分
    if (maxImportance == minImportance && maxImportance > 0) {
      minImportance = maxImportance * 0.8;
    }
    
    // 按重要性排序
    sortedWords.sort((a, b) {
      final aImportance = (a['importance'] is num) 
          ? (a['importance'] as num).toDouble() 
          : ((a['count'] is num) ? (a['count'] as num).toDouble() : 0.0);
      final bImportance = (b['importance'] is num) 
          ? (b['importance'] as num).toDouble() 
          : ((b['count'] is num) ? (b['count'] as num).toDouble() : 0.0);
      return bImportance.compareTo(aImportance);
    });

    // 更丰富的颜色渐变方案（基于重要程度）
    final colorGradients = [
      [const Color(0xFF6366F1), const Color(0xFF8B5CF6)], // 紫色渐变 - 极高重要
      [const Color(0xFF3B82F6), const Color(0xFF60A5FA)], // 蓝色渐变 - 高重要
      [const Color(0xFF10B981), const Color(0xFF34D399)], // 绿色渐变 - 中等重要
      [const Color(0xFFF59E0B), const Color(0xFFFBBF24)], // 橙色渐变 - 一般重要
    ];

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: widget.width,
        height: widget.height ?? 300,
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: const Color(0xFF3B82F6).withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  const Color(0xFFF8FAFC),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: List.generate(sortedWords.length, (index) {
                      final w = sortedWords[index];
                      
                      // 优先使用importance，如果没有则使用count
                      final importance = (w['importance'] is num)
                          ? (w['importance'] as num).toDouble()
                          : ((w['count'] is num)
                              ? (w['count'] as num).toDouble()
                              : 0.0);
                      
                      // 归一化重要性（0-1范围）
                      final normalizedImportance = (maxImportance - minImportance) > 0
                          ? ((importance - minImportance) / (maxImportance - minImportance)).clamp(0.0, 1.0)
                          : (sortedWords.length > 1 
                              ? (sortedWords.length - index) / sortedWords.length 
                              : 0.5); // 如果所有值相同，使用索引位置
                      
                      // 根据重要程度计算字体大小（更大范围，确保有明显差异）
                      // 最小12px，最大48px
                      final fontSize = 12.0 + normalizedImportance * 36.0;
                      
                      // 根据重要程度选择颜色渐变（更明显的区分）
                      int colorIndex;
                      if (normalizedImportance >= 0.8) {
                        colorIndex = 0; // 极高重要 - 紫色
                      } else if (normalizedImportance >= 0.6) {
                        colorIndex = 1; // 高重要 - 蓝色
                      } else if (normalizedImportance >= 0.4) {
                        colorIndex = 2; // 中等重要 - 绿色
                      } else {
                        colorIndex = 3; // 一般重要 - 橙色
                      }
                      
                      final colorPair = colorGradients[colorIndex];
                      // 根据normalizedImportance在颜色对之间插值，产生更丰富的颜色变化
                      final colorProgress = (normalizedImportance % 0.2) / 0.2; // 在每个颜色段内的进度
                      final baseColor = Color.lerp(
                        colorPair[0],
                        colorPair[1],
                        colorProgress.clamp(0.0, 1.0),
                      ) ?? colorPair[0];
                      
                      // 根据重要程度计算透明度和边框宽度
                      final opacity = 0.7 + normalizedImportance * 0.3;
                      final borderWidth = normalizedImportance > 0.7 ? 2.0 : 1.0;
                      
                      // 重要程度标签
                      String importanceLabel = '';
                      Color? labelColor;
                      if (normalizedImportance >= 0.75) {
                        importanceLabel = '极高';
                        labelColor = const Color(0xFF8B5CF6);
                      } else if (normalizedImportance >= 0.5) {
                        importanceLabel = '高';
                        labelColor = const Color(0xFF3B82F6);
                      }
                      
                      return AnimatedBuilder(
                        animation: _wordAnimations[index],
                        builder: (context, child) {
                          final scale = _wordAnimations[index].value;
                          final rotation = (normalizedImportance - 0.5) * 0.1 * (1 - scale);
                          
                          return Transform.scale(
                            scale: scale,
                            child: Transform.rotate(
                              angle: rotation,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10 + normalizedImportance * 6,
                                  vertical: 6 + normalizedImportance * 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      baseColor.withOpacity(0.15),
                                      baseColor.withOpacity(0.08),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: baseColor.withOpacity(opacity * 0.5),
                                    width: borderWidth,
                                  ),
                                  boxShadow: normalizedImportance > 0.7
                                      ? [
                                          BoxShadow(
                                            color: baseColor.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      w['word'].toString(),
                                      style: TextStyle(
                                        fontSize: fontSize,
                                        color: baseColor.withOpacity(opacity),
                                        fontWeight: normalizedImportance > 0.7
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        letterSpacing: 0.5,
                                        shadows: normalizedImportance > 0.7
                                            ? [
                                                Shadow(
                                                  color: baseColor.withOpacity(0.3),
                                                  blurRadius: 4,
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                    if (importanceLabel.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: labelColor!.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: labelColor.withOpacity(0.5),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Text(
                                          importanceLabel,
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: labelColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

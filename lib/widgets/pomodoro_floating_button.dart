import 'package:flutter/material.dart';

/// 可拖拽且自动吸附左右边缘的番茄浮球
class PomodoroFloatingButton extends StatefulWidget {
  final VoidCallback onTap;

  const PomodoroFloatingButton({Key? key, required this.onTap}) : super(key: key);

  @override
  State<PomodoroFloatingButton> createState() => _PomodoroFloatingButtonState();
}

class _PomodoroFloatingButtonState extends State<PomodoroFloatingButton> {
  Offset? _position;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final safeArea = MediaQuery.of(context).padding;
    const double buttonSize = 60.0;
    
    // 获取 AppBar 高度（通常为 56）
    final appBarHeight = AppBar().preferredSize.height;
    
    // Stack 在 body 中，body 的高度 = 屏幕高度 - AppBar 高度
    // Positioned 的坐标是相对于 Stack 的，所以 top 坐标不需要考虑 AppBar
    // 但需要考虑底部导航栏（通常约 60-80px）
    final bottomNavBarHeight = 80.0; // 底部导航栏的估计高度
    
    // 初始化位置：右下角（如果还未初始化）
    // Positioned 的 top 是相对于 Stack（body）的，所以使用 body 的高度
    final bodyHeight = screenSize.height - appBarHeight;
    
    // 使用更保守的初始位置，确保按钮在可见区域内
    // 如果位置还未初始化，设置为右下角
    if (_position == null) {
      // 确保 bodyHeight 是有效的正数
      final validBodyHeight = bodyHeight > 0 ? bodyHeight : screenSize.height * 0.8;
      final initialX = (screenSize.width - buttonSize - 16).clamp(0.0, screenSize.width - buttonSize);
      // 确保 Y 坐标在有效范围内
      final maxY = validBodyHeight - buttonSize - bottomNavBarHeight - 16;
      final initialY = maxY.clamp(10.0, validBodyHeight - buttonSize);
      _position = Offset(initialX, initialY);
      debugPrint('🍅 番茄悬浮按钮初始化: 屏幕=${screenSize.width}x${screenSize.height}, AppBar=$appBarHeight, body高度=$validBodyHeight, 初始位置=($initialX, $initialY)');
    }

    return Positioned(
      left: _position!.dx,
      top: _position!.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _isDragging = true;
            // 实时更新位置并做边界限制
            final appBarHeight = AppBar().preferredSize.height;
            final bodyHeight = screenSize.height - appBarHeight;
            final bottomNavBarHeight = 80.0;
            
            double x = (_position!.dx + details.delta.dx).clamp(0.0, screenSize.width - buttonSize);
            // Y坐标限制，基于 body（Stack）的实际可用区域
            double y = (_position!.dy + details.delta.dy).clamp(
              10.0, // 顶部留出一点边距
              bodyHeight - buttonSize - bottomNavBarHeight - 20 // 底部留出导航栏空间
            );
            _position = Offset(x, y);
          });
        },
        onPanEnd: (_) {
          // 松手后吸附到左右边
          setState(() {
            _isDragging = false;
            final appBarHeight = AppBar().preferredSize.height;
            final bodyHeight = screenSize.height - appBarHeight;
            final bottomNavBarHeight = 80.0;
            
            final bool stickLeft = _position!.dx + buttonSize / 2 < screenSize.width / 2;
            final double finalX = stickLeft ? 10.0 : screenSize.width - buttonSize - 10.0;
            // 限制Y坐标，确保按钮不会超出 body（Stack）的可用区域
            final double finalY = _position!.dy.clamp(
              10.0,
              bodyHeight - buttonSize - bottomNavBarHeight - 20
            );
            _position = Offset(finalX, finalY);
          });
        },
        onTap: () {
          if (!_isDragging) {
            widget.onTap();
          }
        },
        child: AnimatedContainer(
          duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFFC1A8), // 柔和的番茄橙
                Color(0xFFFF8FA3), // 低饱和粉红
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF8FA3).withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.45),
                blurRadius: 14,
                offset: const Offset(-4, -4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.timer_outlined,
                color: Colors.white,
                size: 28,
              ),
              // 小叶子点缀
              Positioned(
                top: 8,
                right: 12,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Color(0xFF6FCF97), // 柔和绿色
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


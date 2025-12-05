import 'package:flutter/material.dart';

/// 可拖拽且自动吸附左右边缘的番茄浮球
class PomodoroFloatingButton extends StatefulWidget {
  final VoidCallback onTap;

  const PomodoroFloatingButton({Key? key, required this.onTap}) : super(key: key);

  @override
  State<PomodoroFloatingButton> createState() => _PomodoroFloatingButtonState();
}

class _PomodoroFloatingButtonState extends State<PomodoroFloatingButton> {
  // 初始位置：右下角偏上
  Offset _position = const Offset(300, 500);
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const double buttonSize = 60.0;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _isDragging = true;
            // 实时更新位置并做边界限制
            double x = (_position.dx + details.delta.dx).clamp(0.0, screenSize.width - buttonSize);
            double y = (_position.dy + details.delta.dy).clamp(0.0, screenSize.height - buttonSize);
            _position = Offset(x, y);
          });
        },
        onPanEnd: (_) {
          // 松手后吸附到左右边
          setState(() {
            _isDragging = false;
            final bool stickLeft = _position.dx + buttonSize / 2 < screenSize.width / 2;
            final double finalX = stickLeft ? 10.0 : screenSize.width - buttonSize - 10.0;
            _position = Offset(finalX, _position.dy);
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


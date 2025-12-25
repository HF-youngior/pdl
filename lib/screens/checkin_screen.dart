import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user.dart';
import '../services/checkin_service.dart';
import 'points_mall_screen.dart';

class CheckinScreen extends StatefulWidget {
  final User user;

  const CheckinScreen({super.key, required this.user});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> with SingleTickerProviderStateMixin {
  late DateTime _selectedDate;
  late DateTime _currentMonth;
  Map<String, bool> _checkinRecords = {};
  int _points = 0;
  int _consecutiveDays = 0;
  bool _isLoading = false; // 初始改为false，先显示页面
  bool _isCheckingIn = false;
  String _serverToday = ''; // 服务端今天的日期字符串
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _loadData(); // 异步加载，不阻塞页面显示
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 将日期字符串减16小时后再加24小时（即加8小时）返回新的日期字符串（用于统一日历和记录显示）
  String _subtract16Hours(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final adjustedDate = date.subtract(const Duration(hours: 16)).add(const Duration(hours: 24));
      return DateFormat('yyyy-MM-dd').format(adjustedDate);
    } catch (e) {
      return dateStr; // 如果解析失败，返回原日期
    }
  }

  Future<void> _loadData() async {
    // 不设置isLoading，让页面先显示，后台更新数据
    try {
      // 先获取服务端日期，确保日期判断一致
      final serverTodayData = await CheckinService.getServerToday();
      final serverTodayStr = serverTodayData['today'] as String;
      
      // 使用Future.wait并行加载数据，提高性能
      final results = await Future.wait([
        CheckinService.getUserPoints(widget.user.id),
        CheckinService.getCheckinRecords(
          widget.user.id,
          _currentMonth.year,
          _currentMonth.month,
        ),
        CheckinService.getConsecutiveDays(widget.user.id),
      ]);

      if (mounted) {
        // 将签到记录的日期都减16小时再加24小时（即加8小时），确保与显示一致
        final originalRecords = results[1] as Map<String, bool>;
        final adjustedRecords = <String, bool>{};
        originalRecords.forEach((dateStr, value) {
          final adjustedDate = _subtract16Hours(dateStr);
          adjustedRecords[adjustedDate] = value;
        });
        
        setState(() {
          _serverToday = serverTodayStr;
          _points = results[0] as int;
          _checkinRecords = adjustedRecords;
          _consecutiveDays = results[2] as int;
        });
      }
    } catch (e) {
      print('加载数据异常: $e');
      // 静默失败，使用默认值，不影响用户体验
      if (mounted && _serverToday.isEmpty) {
        // 如果服务端日期获取失败，使用本地日期作为fallback
        final now = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);
        setState(() {
          _serverToday = todayStr;
        });
      }
    }
  }

  Future<void> _handleCheckin() async {
    // 确保服务端日期已加载
    String todayStr = _serverToday;
    if (todayStr.isEmpty) {
      try {
        final serverTodayData = await CheckinService.getServerToday();
        todayStr = serverTodayData['today'] as String;
        if (mounted) {
          setState(() {
            _serverToday = todayStr;
          });
        }
      } catch (e) {
        // 如果获取服务端日期失败，使用本地日期作为fallback
        final now = DateTime.now();
        todayStr = DateFormat('yyyy-MM-dd').format(now);
      }
    }
    
    // 检查今天是否已签到（使用服务端日期）
    if (_checkinRecords[todayStr] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('今天已经签到过了哦~')),
        );
      }
      return;
    }

    setState(() {
      _isCheckingIn = true;
    });

    try {
      final result = await CheckinService.checkin(widget.user.id);
      final pointsEarned = (result['pointsEarned'] as num?)?.toInt() ?? 5;
      final points = (result['points'] as num?)?.toInt() ?? (_points + pointsEarned);
      final consecutiveDays = (result['consecutiveDays'] as num?)?.toInt() ?? (_consecutiveDays + 1);
      final checkinDate = result['checkinDate'] as String? ?? todayStr;
      
      // 更新本地状态（使用服务端返回的日期，减16小时再加24小时（即加8小时）后存储）
      if (mounted) {
        final adjustedCheckinDate = _subtract16Hours(checkinDate);
        setState(() {
          _checkinRecords[adjustedCheckinDate] = true;
          _points = points;
          _consecutiveDays = consecutiveDays;
        });

        _animationController.forward().then((_) {
          _animationController.reverse();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('签到成功！获得 $pointsEarned 积分 🎉'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // 后台静默刷新数据以确保同步，但不阻塞UI
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('签到失败: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingIn = false;
        });
      }
    }
  }

  void _goToPointsMall() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PointsMallScreen(
          user: widget.user,
          totalPoints: _points,
        ),
      ),
    );
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    // 异步加载，不阻塞UI
    _loadData();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    // 异步加载，不阻塞UI
    _loadData();
  }

  bool _isToday(DateTime date) {
    // 使用服务端日期字符串进行比较，确保时区一致
    if (_serverToday.isEmpty) {
      // 如果服务端日期未加载，使用本地日期作为fallback
      final today = DateTime.now();
      return date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
    }
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return dateStr == _serverToday;
  }

  bool _isCheckedIn(DateTime date) {
    // 使用统一的日期格式，确保与服务端返回的日期格式一致
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return _checkinRecords[dateStr] == true;
  }

  @override
  Widget build(BuildContext context) {
    // 使用服务端日期判断今天
    final todayStr = _serverToday.isNotEmpty 
        ? _serverToday 
        : DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    // 解析服务端日期来确定当前月份
    DateTime todayDate;
    if (_serverToday.isNotEmpty) {
      final parts = _serverToday.split('-');
      todayDate = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } else {
      todayDate = DateTime.now();
    }
    
    final isCurrentMonth = _currentMonth.year == todayDate.year && 
        _currentMonth.month == todayDate.month;
    final isCheckedInToday = _checkinRecords[todayStr] == true;
    final canCheckin = isCurrentMonth && !isCheckedInToday && !_isCheckingIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('每日签到'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _isCheckingIn ? null : () {
              setState(() {
                _isLoading = true;
              });
              _loadData().then((_) {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue[50]!,
                    Colors.purple[50]!,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildCheckinButton(canCheckin, isCurrentMonth, isCheckedInToday),
                      const SizedBox(height: 24),
                      _buildPointsCard(),
                      const SizedBox(height: 24),
                      _buildCalendar(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildPointsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                label: '总积分',
                value: '$_points',
                icon: Icons.stars_rounded,
                gradientColors: [const Color(0xFF7AD7F0), const Color(0xFF5AA3F5)],
                hintText: '点击兑换',
                onTap: _goToPointsMall,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                label: '连续签到',
                value: '$_consecutiveDays 天',
                icon: Icons.calendar_today_rounded,
                gradientColors: [const Color(0xFF7DE5B3), const Color(0xFF47C18E)],
                hintText: '保持打卡',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required List<Color> gradientColors,
    String? hintText,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: gradientColors.last.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                  if (hintText != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      hintText,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckinButton(bool canCheckin, bool isCurrentMonth, bool isCheckedInToday) {
    // 如果当天已签到，使用绿色渐变；如果可以签到，使用红色渐变；否则使用灰色
    final gradient = isCheckedInToday
        ? [Colors.green[400]!, Colors.green[600]!]
        : canCheckin
            ? [const Color(0xFFFFAA85), const Color(0xFFFD4C77)]
            : [Colors.grey[400]!, Colors.grey[500]!];

    return Column(
      children: [
        Text(
          '每日签到',
          style: TextStyle(
            color: Colors.grey[800],
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_animation.value * 0.1),
              child: child,
            );
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  Colors.pink[50]!,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.pink.withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                // 如果已签到或正在签到中，禁用按钮
                onTap: canCheckin ? _handleCheckin : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: gradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: gradient.last.withOpacity(0.45),
                              blurRadius: 16,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: _isCheckingIn
                            ? const Center(
                                child: CircularProgressIndicator(color: Colors.white),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isCheckedInToday
                                        ? Icons.check_circle_rounded
                                        : canCheckin
                                            ? Icons.check_circle_outline_rounded
                                            : Icons.lock_clock_rounded,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isCheckedInToday
                                        ? '已签到'
                                        : canCheckin
                                            ? '签到'
                                            : '已完成',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isCheckedInToday
                            ? '今天已经签到过了，明天继续哦'
                            : canCheckin
                                ? '今日还未签到，点击领取奖励'
                                : (isCurrentMonth
                                    ? '今天的签到已完成，明天继续哦'
                                    : '请切换到本月进行签到'),
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendar() {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstDayWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday, 6 = Saturday
    final daysInMonth = lastDayOfMonth.day;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.blue[50]!,
            Colors.purple[50]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                _buildCalendarNavButton(Icons.chevron_left_rounded, _previousMonth),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        DateFormat('yyyy年').format(_currentMonth),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        DateFormat('MM月').format(_currentMonth),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildCalendarNavButton(Icons.chevron_right_rounded, _nextMonth),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueGrey.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: ['日', '一', '二', '三', '四', '五', '六']
                    .map(
                      (day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),
            ...List.generate((daysInMonth + firstDayWeekday + 6) ~/ 7, (weekIndex) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: List.generate(7, (dayIndex) {
                    final dateIndex = weekIndex * 7 + dayIndex - firstDayWeekday;

                    if (dateIndex < 0 || dateIndex >= daysInMonth) {
                      return const Expanded(child: SizedBox());
                    }

                    final date = DateTime(_currentMonth.year, _currentMonth.month, dateIndex + 1);
                    final isToday = _isToday(date);
                    final isCheckedIn = _isCheckedIn(date);

                    return Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isCheckedIn
                                  ? Colors.green[400]!
                                  : isToday
                                      ? Theme.of(context).primaryColor
                                      : Colors.white,
                              width: isToday ? 2 : 1.2,
                            ),
                            gradient: isCheckedIn
                                ? LinearGradient(
                                    colors: [
                                      Colors.green[400]!,
                                      Colors.green[600]!,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: (isCheckedIn
                                        ? Colors.green
                                        : Theme.of(context).primaryColor)
                                    .withOpacity(isToday || isCheckedIn ? 0.25 : 0.06),
                                blurRadius: isToday || isCheckedIn ? 12 : 6,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${date.day}',
                                style: TextStyle(
                                  color: isCheckedIn
                                      ? Colors.white
                                      : isToday
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey[800],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (isCheckedIn)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              if (!isCheckedIn && isToday)
                                Icon(
                                  Icons.radio_button_checked,
                                  size: 8,
                                  color: Theme.of(context).primaryColor,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarNavButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: IconButton(
        icon: Icon(icon, color: Theme.of(context).primaryColor),
        onPressed: onTap,
      ),
    );
  }
}


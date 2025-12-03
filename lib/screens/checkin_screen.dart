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
  bool _isLoading = true;
  bool _isCheckingIn = false;
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
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 使用Future.wait并行加载数据，提高性能
      final results = await Future.wait([
        CheckinService.getUserPoints(widget.user.id).catchError((e) {
          print('获取积分失败: $e');
          return 0; // 失败时返回0
        }),
        CheckinService.getCheckinRecords(
          widget.user.id,
          _currentMonth.year,
          _currentMonth.month,
        ).catchError((e) {
          print('获取签到记录失败: $e');
          return <String, bool>{}; // 失败时返回空记录
        }),
        CheckinService.getConsecutiveDays(widget.user.id).catchError((e) {
          print('获取连续签到天数失败: $e');
          return 0; // 失败时返回0
        }),
      ]);

      setState(() {
        _points = results[0] as int;
        _checkinRecords = results[1] as Map<String, bool>;
        _consecutiveDays = results[2] as int;
        _isLoading = false;
      });
    } catch (e) {
      print('加载数据异常: $e');
      setState(() {
        _isLoading = false;
        // 即使出错，也设置默认值，避免页面显示异常
        _points = 0;
        _checkinRecords = {};
        _consecutiveDays = 0;
      });
      // 不显示错误提示，因为已经设置了默认值
      // 如果确实有问题，用户会在签到操作时看到错误
    }
  }

  Future<void> _handleCheckin() async {
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    
    // 检查今天是否已签到
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
      final points = result['points'] ?? _points + 5;
      
      // 更新本地状态
      setState(() {
        _checkinRecords[todayStr] = true;
        _points = points;
        _consecutiveDays = result['consecutiveDays'] ?? _consecutiveDays + 1;
      });

      _animationController.forward().then((_) {
        _animationController.reverse();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('签到成功！获得 5 积分 🎉'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // 重新加载数据以确保同步
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('签到失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isCheckingIn = false;
      });
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
    _loadData();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    _loadData();
  }

  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  bool _isCheckedIn(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return _checkinRecords[dateStr] == true;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    final isCurrentMonth = _currentMonth.year == today.year && _currentMonth.month == today.month;
    final canCheckin = isCurrentMonth && !(_checkinRecords[todayStr] == true);

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
            onPressed: _isLoading ? null : _loadData,
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
                      _buildCheckinButton(canCheckin, isCurrentMonth),
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

  Widget _buildCheckinButton(bool canCheckin, bool isCurrentMonth) {
    final gradient = canCheckin
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
                onTap: canCheckin && !_isCheckingIn ? _handleCheckin : null,
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
                                    canCheckin ? Icons.check_circle_rounded : Icons.lock_clock_rounded,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    canCheckin ? '签到' : '已完成',
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
                      canCheckin
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


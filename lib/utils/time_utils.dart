/// 时间工具类
/// 用于处理时区转换和时间格式化
class TimeUtils {
  static const Duration _beijingOffset = Duration(hours: 8);
  static const String _beijingLabel = 'UTC+08:00 北京时间';

  /// 获取系统本地时间
  static DateTime getSystemTime() {
    return DateTime.now();
  }
  
  /// 检查两个日期是否是同一天（本地时间）
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
  
  /// 检查日期是否是今天（本地时间）
  static bool isToday(DateTime date) {
    final now = getSystemTime();
    return isSameDay(date, now);
  }
  
  /// 格式化时间为 HH:mm
  static String formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  
  /// 格式化时间为 HH:mm:ss
  static String formatTimeWithSeconds(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
  
  /// 格式化日期为 yyyy-MM-dd
  static String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  /// 格式化日期时间为 yyyy-MM-dd HH:mm
  static String formatDateTime(DateTime dateTime) {
    return '${formatDate(dateTime)} ${formatTime(dateTime)}';
  }
  
  /// 获取时区偏移字符串（例如 UTC+08:00）
  static String formatTimeZoneOffset(DateTime dateTime) {
    return _beijingLabel;
  }
  
  /// 带时区标签的日期时间格式（默认精确到分钟）
  static String formatDateTimeWithZone(
    DateTime dateTime, {
    bool includeSeconds = false,
    String? label,
    bool useBeijingTime = true,
  }) {
    final localDateTime = useBeijingTime ? _toBeijing(dateTime) : dateTime;
    final timeString = includeSeconds
        ? formatTimeWithSeconds(localDateTime)
        : formatTime(localDateTime);
    final zoneLabel = useBeijingTime
        ? _beijingLabel
        : _formatDeviceOffset(localDateTime);
    final suffix = label != null && label.isNotEmpty ? ' $label' : '';
    return '${formatDate(localDateTime)} $timeString ($zoneLabel$suffix)';
  }

  static DateTime _toBeijing(DateTime dateTime) {
    final utcDateTime = dateTime.isUtc ? dateTime : dateTime.toUtc();
    return utcDateTime.add(_beijingOffset);
  }
  
  /// 将UTC时间转换为本地时间
  static DateTime utcToLocal(DateTime utcTime) {
    return utcTime.toLocal();
  }
  
  /// 将本地时间转换为UTC时间
  static DateTime localToUtc(DateTime localTime) {
    return localTime.toUtc();
  }
  
  /// 获取今天的开始时间（本地时间 00:00:00）
  static DateTime getTodayStart() {
    final now = getSystemTime();
    return DateTime(now.year, now.month, now.day, 0, 0, 0);
  }
  
  /// 获取今天的结束时间（本地时间 23:59:59）
  static DateTime getTodayEnd() {
    final now = getSystemTime();
    return DateTime(now.year, now.month, now.day, 23, 59, 59);
  }
  
  /// 获取指定日期的开始时间（00:00:00）
  static DateTime getDayStart(DateTime date) {
    return DateTime(date.year, date.month, date.day, 0, 0, 0);
  }
  
  /// 获取指定日期的结束时间（23:59:59）
  static DateTime getDayEnd(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }
  
  /// 计算小时和分钟的浮点数表示（用于时间轴定位）
  static double getHourWithMinutes(DateTime time) {
    return time.hour + time.minute / 60.0;
  }

  static String _formatDeviceOffset(DateTime dateTime) {
    final offset = dateTime.timeZoneOffset;
    final totalMinutes = offset.inMinutes;
    final sign = totalMinutes >= 0 ? '+' : '-';
    final hours = (totalMinutes.abs() ~/ 60).toString().padLeft(2, '0');
    final minutes = (totalMinutes.abs() % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hours:$minutes 本地时区';
  }
}


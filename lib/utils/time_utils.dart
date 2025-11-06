/// 时间工具类
/// 用于处理时区转换和时间格式化
class TimeUtils {
  // 北京时区偏移（UTC+8）
  static const int beijingOffset = 8;
  
  /// 获取北京时间
  static DateTime getBeijingTime() {
    final now = DateTime.now().toUtc();
    return now.add(const Duration(hours: beijingOffset));
  }
  
  /// 检查两个日期是否是同一天（北京时间）
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
  
  /// 检查日期是否是今天（北京时间）
  static bool isToday(DateTime date) {
    final beijingNow = getBeijingTime();
    return isSameDay(date, beijingNow);
  }
  
  /// 格式化时间为 HH:mm
  static String formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
  
  /// 格式化日期为 yyyy-MM-dd
  static String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  /// 格式化日期时间为 yyyy-MM-dd HH:mm
  static String formatDateTime(DateTime dateTime) {
    return '${formatDate(dateTime)} ${formatTime(dateTime)}';
  }
  
  /// 将UTC时间转换为北京时间
  static DateTime utcToBeijing(DateTime utcTime) {
    return utcTime.add(const Duration(hours: beijingOffset));
  }
  
  /// 将北京时间转换为UTC时间
  static DateTime beijingToUtc(DateTime beijingTime) {
    return beijingTime.subtract(const Duration(hours: beijingOffset));
  }
  
  /// 获取今天的开始时间（北京时间 00:00:00）
  static DateTime getTodayStart() {
    final beijingNow = getBeijingTime();
    return DateTime(beijingNow.year, beijingNow.month, beijingNow.day, 0, 0, 0);
  }
  
  /// 获取今天的结束时间（北京时间 23:59:59）
  static DateTime getTodayEnd() {
    final beijingNow = getBeijingTime();
    return DateTime(beijingNow.year, beijingNow.month, beijingNow.day, 23, 59, 59);
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
}


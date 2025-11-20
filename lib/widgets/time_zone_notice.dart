import 'package:flutter/material.dart';
import '../utils/time_utils.dart';

class TimeZoneNotice extends StatelessWidget {
  final EdgeInsetsGeometry? margin;
  final String? description;
  final bool includeSeconds;

  const TimeZoneNotice({
    super.key,
    this.margin,
    this.description,
    this.includeSeconds = false,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeLabel = TimeUtils.formatDateTimeWithZone(
      now,
      includeSeconds: includeSeconds,
      useBeijingTime: false,
    );
    final desc = description ??
        '所有时间字段均按当前设备本地时区展示，便于与 Web 管理端核对。';

    return Container(
      margin: margin ?? const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.access_time,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '当前本地时间基准：$timeLabel',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


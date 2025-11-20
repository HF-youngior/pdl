import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/time_utils.dart';

class TimeZoneNotice extends StatefulWidget {
  final EdgeInsetsGeometry? margin;
  final String? description;
  final bool includeSeconds;
  final Duration refreshInterval;

  const TimeZoneNotice({
    super.key,
    this.margin,
    this.description,
    this.includeSeconds = false,
    this.refreshInterval = const Duration(seconds: 1),
  });

  @override
  State<TimeZoneNotice> createState() => _TimeZoneNoticeState();
}

class _TimeZoneNoticeState extends State<TimeZoneNotice> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _startTicker();
  }

  @override
  void didUpdateWidget(covariant TimeZoneNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshInterval != widget.refreshInterval) {
      _startTicker();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _timer?.cancel();
    if (widget.refreshInterval.inMilliseconds <= 0) return;
    _timer = Timer.periodic(widget.refreshInterval, (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = TimeUtils.formatDateTimeWithZone(
      _now,
      includeSeconds: widget.includeSeconds,
      useBeijingTime: false,
    );
    final desc = widget.description ??
        '系统已自动使用当前设备的本地时区展示所有时间。';

    return Container(
      margin: widget.margin ?? const EdgeInsets.fromLTRB(16, 8, 16, 0),
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


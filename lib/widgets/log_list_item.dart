import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/log.dart';

class LogListItem extends StatelessWidget {
  final Log log;
  final VoidCallback onTap;

  const LogListItem({
    super.key,
    required this.log,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final weatherEmoji = log.getWeatherEmoji();
    final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(log.createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        
        // 左侧：Q版天气图标
        leading: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1.5),
          ),
          child: Center(
            child: Text(
              weatherEmoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        
        // 主内容
        title: Text(
          log.action,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            decoration: log.isCompletedBool ? TextDecoration.lineThrough : null,
            color: log.isCompletedBool ? Colors.grey : null,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              formattedDate,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            if (log.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                log.description,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        
        // 右侧：完成状态图标
        trailing: Icon(
          log.isCompletedBool ? Icons.check_circle : Icons.radio_button_unchecked,
          color: log.isCompletedBool ? Colors.green : Colors.grey.shade400,
          size: 20,
        ),
      ),
    );
  }
}

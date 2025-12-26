-- Insert 8 personal_logs for user admin-001 (username: admin)
USE enterprise_management;

-- 为避免重复插入，使用 INSERT IGNORE（如需强制更新请改为 REPLACE 或先 DELETE）

INSERT IGNORE INTO personal_logs (
  id,
  log_id,
  user_id,
  title,
  content,
  is_completed,
  created_at,
  log_date,
  weather,
  keywords,
  log_title,
  log_content,
  category,
  quadrant,
  is_archived,
  related_task_id
) VALUES
-- 1
('admin-log-001', 'alog-001', 'admin-001', '系统运维巡检', '完成服务器资源巡检与日志清理，磁盘使用率降至70%以内。', TRUE, '2025-10-15 09:30:00', '2025-10-15', 'sunny', '巡检,服务器,磁盘', '系统运维巡检', '完成服务器资源巡检与日志清理，磁盘使用率降至70%以内。', 'work', 'important_not_urgent', FALSE, NULL),
-- 2
('admin-log-002', 'alog-002', 'admin-001', '季度发布计划评审', '组织本季度发布计划评审会议，梳理风险点与回滚预案。', TRUE, '2025-10-16 11:00:00', '2025-10-16', 'cloudy', '发布,评审,预案', '季度发布计划评审', '组织本季度发布计划评审会议，梳理风险点与回滚预案。', 'work', 'important_urgent', FALSE, NULL),
-- 3
('admin-log-003', 'alog-003', 'admin-001', '监控告警优化', '调整Prometheus与报警阈值，减少无效告警，新增延迟聚合面板。', FALSE, '2025-10-17 15:20:00', '2025-10-17', 'light_rain', '监控,告警,Prometheus', '监控告警优化', '调整Prometheus与报警阈值，减少无效告警，新增延迟聚合面板。', 'work', 'important_not_urgent', FALSE, NULL),
-- 4
('admin-log-004', 'alog-004', 'admin-001', '安全巡检与账号治理', '完成高风险账号复核与过期密钥清理，补充操作审计说明。', TRUE, '2025-10-18 10:10:00', '2025-10-18', 'sunny', '安全,账号,密钥', '安全巡检与账号治理', '完成高风险账号复核与过期密钥清理，补充操作审计说明。', 'work', 'important_urgent', FALSE, NULL),
-- 5
('admin-log-005', 'alog-005', 'admin-001', '备份策略回顾', '检查全量与增量备份一致性，抽样恢复验证通过，记录RTO/RPO指标。', TRUE, '2025-10-19 14:05:00', '2025-10-19', 'cloudy', '备份,恢复,一致性', '备份策略回顾', '检查全量与增量备份一致性，抽样恢复验证通过，记录RTO/RPO指标。', 'work', 'important_not_urgent', FALSE, NULL),
-- 6
('admin-log-006', 'alog-006', 'admin-001', '发布流程优化讨论', '与研发、测试、运维共同评审蓝绿发布流程，确定灰度策略基线。', FALSE, '2025-10-20 16:40:00', '2025-10-20', 'sunny', '蓝绿,灰度,流程', '发布流程优化讨论', '与研发、测试、运维共同评审蓝绿发布流程，确定灰度策略基线。', 'work', 'not_important_urgent', FALSE, NULL),
-- 7
('admin-log-007', 'alog-007', 'admin-001', '成本优化月报', '整理云资源使用与费用结构，提出关停低利用率实例与存储分层建议。', TRUE, '2025-10-21 09:10:00', '2025-10-21', 'cloudy', '成本,云资源,优化', '成本优化月报', '整理云资源使用与费用结构，提出关停低利用率实例与存储分层建议。', 'work', 'important_not_urgent', FALSE, NULL),
-- 8
('admin-log-008', 'alog-008', 'admin-001', '应急演练复盘', '完成故障应急演练复盘，记录处置时间线与改进项，更新演练手册。', TRUE, '2025-10-22 17:25:00', '2025-10-22', 'storm', '演练,复盘,改进', '应急演练复盘', '完成故障应急演练复盘，记录处置时间线与改进项，更新演练手册。', 'work', 'important_urgent', FALSE, NULL);



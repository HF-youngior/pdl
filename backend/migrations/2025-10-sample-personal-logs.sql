-- 示例数据（确保对应 users 与 tasks 中存在相应ID）

INSERT INTO personal_logs (log_id, user_id, log_date, weather, keywords, log_title, log_content, category, quadrant, is_archived)
VALUES
('a1b2c3d4-e5f6-7890-a1b2-c3d4e5f67890', 'employee-001', '2025-10-15', 'sunny',     '需求评审,UI优化,性能测试', 'Q4需求评审总结',   '今天完成了Q4主流程的需求评审，整理风险点与依赖。', 'work', 'important_not_urgent', FALSE),
('b1c2d3e4-f5a6-7890-b1c2-d3e4f5a67890', 'employee-001', '2025-10-15', 'cloudy',    '接口联调,异常处理',       '接口联调与异常兜底', '与后端完成登录与任务列表接口联调，梳理异常场景。',  'work', 'important_urgent',     FALSE),
('c1d2e3f4-a5b6-7890-c1d2-e3f4a5b67890', 'employee-001', '2025-10-16', 'light_rain','代码走查,单元测试',       '代码走查与UT补齐',   '完成任务服务的走查并补齐了关键路径的单测。',       'work', 'not_important_urgent', FALSE),
('d1e2f3a4-b5c6-7890-d1e2-f3a4b5c67890', 'employee-001', '2025-10-16', 'heavy_rain','UI细节,交互优化',         '编辑器交互微调',     '对日志编辑器的日期/天气/关键词交互做了优化。',      'work', 'important_not_urgent', FALSE),
('e1f2a3b4-c5d6-7890-e1f2-a3b4c5d67890', 'employee-001', '2025-10-17', 'fog',       '埋点,性能监控',           '埋点与性能监控上报', '新增关键行为埋点并接入监控平台，观察首屏指标。',     'work', 'important_not_urgent', FALSE);

INSERT INTO log_task_linkage (log_id, task_id, progress_percentage, task_status)
VALUES
('a1b2c3d4-e5f6-7890-a1b2-c3d4e5f67890', 'task-101', 40, 'in_progress'),
('a1b2c3d4-e5f6-7890-a1b2-c3d4e5f67890', 'task-102', 20, 'in_progress'),
('b1c2d3e4-f5a6-7890-b1c2-d3e4f5a67890', 'task-101', 60, 'in_progress'),
('c1d2e3f4-a5b6-7890-c1d2-e3f4a5b67890', 'task-103', 100, 'completed'),
('d1e2f3a4-b5c6-7890-d1e2-f3a4b5c67890', 'task-104', 30, 'in_progress'),
('d1e2f3a4-b5c6-7890-d1e2-f3a4b5c67890', 'task-102', 50, 'in_progress'),
('e1f2a3b4-c5d6-7890-e1f2-a3b4c5d67890', 'task-105', 10, 'in_progress');



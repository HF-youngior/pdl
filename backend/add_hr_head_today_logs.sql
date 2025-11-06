-- 为 hr_head 用户添加今日日志数据
-- 用户ID: dept-head-001 (王人事总监)
-- 日期: 2025年11月6日

USE enterprise_management;

-- 临时禁用外键检查
SET FOREIGN_KEY_CHECKS = 0;

-- 删除今天可能存在的旧日志（避免重复）
DELETE FROM personal_logs 
WHERE user_id = 'dept-head-001' 
  AND (
    (log_date IS NOT NULL AND DATE(log_date) = CURDATE())
    OR (log_date IS NULL AND DATE(created_at) = CURDATE())
  )
  AND id LIKE 'log-hr-head-today-%';

-- 重新启用外键检查
SET FOREIGN_KEY_CHECKS = 1;

-- 插入今日日志数据
INSERT INTO personal_logs (
  id, 
  log_id,
  user_id, 
  title,
  content,
  log_title,
  log_content,
  category, 
  quadrant,
  is_completed, 
  created_at,
  log_date,
  weather,
  keywords
) VALUES
-- 上午工作日志
('log-hr-head-today-001', UUID(), 'dept-head-001', 'Q4招聘进度会议', 
 '今天上午召开了Q4招聘进度会议，各部门汇报了招聘进展。技术部门已完成70%的招聘目标，市场部门完成60%，财务部门完成80%。整体进度良好，预计月底前能完成所有招聘任务。',
 'Q4招聘进度会议',
 '今天上午召开了Q4招聘进度会议，各部门汇报了招聘进展。技术部门已完成70%的招聘目标，市场部门完成60%，财务部门完成80%。整体进度良好，预计月底前能完成所有招聘任务。',
 'work', 
 'important_urgent', 
 1, 
 NOW(),
 CURDATE(),
 'sunny',
 '招聘,会议,进度,Q4'),

-- 中午学习日志
('log-hr-head-today-002', UUID(), 'dept-head-001', '学习最新劳动法', 
 '中午抽空学习了最新发布的劳动法修订内容，重点关注了员工权益保护、劳动合同解除、加班补偿等条款的变化。这些新规定将影响我们明年的HR政策制定。',
 '学习最新劳动法',
 '中午抽空学习了最新发布的劳动法修订内容，重点关注了员工权益保护、劳动合同解除、加班补偿等条款的变化。这些新规定将影响我们明年的HR政策制定。',
 'study', 
 'important_not_urgent', 
 1, 
 NOW(),
 CURDATE(),
 'sunny',
 '学习,劳动法,政策,HR'),

-- 下午工作日志
('log-hr-head-today-003', UUID(), 'dept-head-001', '员工满意度调研分析', 
 '完成了10月份员工满意度调研的数据分析。整体满意度为85分，较上月提升3分。员工对工作环境、团队协作、职业发展机会等方面评价较高，但在薪酬福利和工作压力方面还有改进空间。已制定改进计划。',
 '员工满意度调研分析',
 '完成了10月份员工满意度调研的数据分析。整体满意度为85分，较上月提升3分。员工对工作环境、团队协作、职业发展机会等方面评价较高，但在薪酬福利和工作压力方面还有改进空间。已制定改进计划。',
 'work', 
 'important_not_urgent', 
 1, 
 NOW(),
 CURDATE(),
 'sunny',
 '员工满意度,调研,数据分析,改进'),

-- 晚上个人日志
('log-hr-head-today-004', UUID(), 'dept-head-001', '家庭聚餐', 
 '晚上和家人一起在家做了顿丰盛的晚餐，做了红烧肉、清蒸鱼和几个小菜。一家人围坐在一起，聊了聊工作和生活，感觉很温馨。',
 '家庭聚餐',
 '晚上和家人一起在家做了顿丰盛的晚餐，做了红烧肉、清蒸鱼和几个小菜。一家人围坐在一起，聊了聊工作和生活，感觉很温馨。',
 'personal', 
 'not_important_not_urgent', 
 1, 
 NOW(),
 CURDATE(),
 'sunny',
 '家庭,聚餐,生活,温馨');

-- 显示插入结果
SELECT 
  '今日日志添加完成' AS message,
  COUNT(*) AS log_count,
  CURDATE() AS log_date
FROM personal_logs 
WHERE user_id = 'dept-head-001' 
  AND (
    (log_date IS NOT NULL AND DATE(log_date) = CURDATE())
    OR (log_date IS NULL AND DATE(created_at) = CURDATE())
  );


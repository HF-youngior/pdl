-- ================================
-- 更新 rich_hr_data 中的日志类别
-- 将所有日志分为 work(工作)、meeting(会议)、learning(学习)、personal(个人) 四类
-- 比例: work ~40%, meeting ~32%, learning ~16%, personal ~12%
-- ================================

USE enterprise_management;

-- 更新为 meeting (会议类) - 约40条
UPDATE personal_logs SET category = 'meeting' WHERE id IN (
    'log-hr-rich-001', -- 秋季校园招聘启动会
    'log-hr-rich-006', -- 部门周会-工作部署
    'log-hr-rich-010', -- 人才梯队建设研讨会
    'log-hr-rich-017', -- 准备董事会人力资源报告
    'log-hr-rich-026', -- 清华大学校园宣讲会
    'log-hr-rich-027', -- 北京大学校园招聘
    'log-hr-rich-028', -- 中国人民大学宣讲会
    'log-hr-rich-036', -- 人才盘点战略会议
    'log-hr-rich-037', -- 绩效管理培训成功举办
    'log-hr-rich-040', -- 上海交通大学宣讲会
    'log-hr-rich-041', -- 复旦大学校园招聘
    'log-hr-rich-044', -- 浙江大学校园招聘
    'log-hr-rich-045', -- 杭州高校招聘收官
    'log-hr-rich-054', -- 深圳站校园招聘启动
    'log-hr-rich-055', -- HR系统实施启动会
    'log-hr-rich-057', -- 哈工大深圳校区宣讲会
    'log-hr-rich-058', -- 深圳大学校园招聘
    'log-hr-rich-060', -- HR数字化需求梳理
    'log-hr-rich-062', -- 发布员工福利升级方案
    'log-hr-rich-066', -- 年度员工大会筹备启动
    'log-hr-rich-067', -- Q4人才盘点启动
    'log-hr-rich-068', -- 与创始人沟通年度规划
    'log-hr-rich-072', -- 技术人才保留策略讨论
    'log-hr-rich-083', -- 劳动法规培训组织
    'log-hr-rich-089', -- 职业发展辅导阶段总结
    'log-hr-rich-091', -- 完成人才盘点报告
    'log-hr-rich-092', -- 人才盘点高层汇报会
    'log-hr-rich-093', -- 年终奖方案高层评审
    'log-hr-rich-094', -- 管理培训生项目获批
    'log-hr-rich-095', -- 庆祝团队阶段性成果
    'log-hr-rich-097', -- Q4团建活动第一天
    'log-hr-rich-098', -- Q4团建活动圆满结束
    'log-hr-rich-108', -- HR系统第一轮培训
    'log-hr-rich-109', -- 员工健康讲座组织
    'log-hr-rich-113', -- 年度员工大会筹备推进
    'log-hr-rich-114', -- HR系统第二轮培训
    'log-hr-rich-121', -- HR系统用户培训收尾
    'log-hr-rich-122', -- 年度员工大会彩排安排
    'log-hr-rich-104', -- 年度人力资源规划获批
    'log-hr-rich-106' -- 年度员工大会流程设计
);

-- 更新为 learning (学习类) - 约20条
UPDATE personal_logs SET category = 'learning' WHERE id IN (
    'log-hr-rich-003', -- 查阅最新劳动法规更新
    'log-hr-rich-008', -- 与IT部门讨论HR系统升级
    'log-hr-rich-025', -- 参加行业人力资源峰会
    'log-hr-rich-029', -- 薪酬调研数据整理
    'log-hr-rich-030', -- 团队凝聚力建设讨论
    'log-hr-rich-043', -- 思考组织文化建设
    'log-hr-rich-056', -- 团建活动供应商对接
    'log-hr-rich-073', -- 完成3位员工职业辅导
    'log-hr-rich-074', -- 撰写人才保留分析报告
    'log-hr-rich-075', -- 管理培训生项目方案设计
    'log-hr-rich-076', -- 员工健康管理计划启动
    'log-hr-rich-078', -- 年度员工大会奖项设计
    'log-hr-rich-086', -- 思考人力资源数字化转型
    'log-hr-rich-099', -- 团建活动总结与反思
    'log-hr-rich-100', -- HR系统用户培训准备
    'log-hr-rich-102', -- 员工职业辅导项目收尾
    'log-hr-rich-103', -- 完成劳动法规培训效果评估
    'log-hr-rich-115', -- 思考2026年HR战略重点
    'log-hr-rich-117', -- 管理培训生项目详细方案
    'log-hr-rich-120' -- 完成人才梯队建设规划
);

-- 更新为 personal (个人类) - 约16条
UPDATE personal_logs SET category = 'personal' WHERE id IN (
    'log-hr-rich-012', -- 处理员工调岗申请
    'log-hr-rich-016', -- 处理劳动纠纷咨询
    'log-hr-rich-019', -- 跟进员工投诉处理进展
    'log-hr-rich-020', -- 员工关系风险排查
    'log-hr-rich-024', -- 撰写人力资源月报
    'log-hr-rich-047', -- 处理员工家庭困难申请
    'log-hr-rich-048', -- 员工关怀机制讨论
    'log-hr-rich-061', -- 10月工作总结与反思
    'log-hr-rich-065', -- 11月工作计划制定
    'log-hr-rich-081', -- HR系统开发进度检查
    'log-hr-rich-084', -- 完成年度人力资源规划初稿
    'log-hr-rich-087', -- 参加双十一团建活动
    'log-hr-rich-105', -- 处理员工离职挽留
    'log-hr-rich-118', -- 处理员工内部矛盾
    'log-hr-rich-124', -- 11月工作总结与12月展望
    'log-hr-rich-125' -- 11月人力资源数据汇总
);

-- 其余所有日志更新为 work (工作类) - 约50条
UPDATE personal_logs SET category = 'work' WHERE id LIKE 'log-hr-rich-%'
    AND category NOT IN ('meeting', 'learning', 'personal');

-- 验证更新结果
SELECT 
    category,
    COUNT(*) as 数量,
    CONCAT(ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM personal_logs WHERE id LIKE 'log-hr-rich-%'), 1), '%') as 占比
FROM personal_logs
WHERE id LIKE 'log-hr-rich-%'
GROUP BY category
ORDER BY COUNT(*) DESC;

SELECT '日志类别更新完成！' as 完成信息;


-- ========================================
-- 为剩余的 HR Head 任务补充详细描述
-- ========================================

USE enterprise_management;

-- ========== 10月剩余任务 ==========

UPDATE tasks SET description = '规划组织能力提升项目，包括组织诊断、能力模型构建、提升方案设计等。通过系统化方法提升组织整体能力，支持战略目标实现。'
WHERE id = 'task-hr-oct-010';

-- ========== 11月剩余任务（101-120系列）==========

UPDATE tasks SET description = '制定年度人力资源战略规划，分析内外部环境，明确HR战略目标和重点工作。包括人才战略、组织发展、文化建设等方面，支持公司战略落地。'
WHERE id = 'task-hr-nov-101';

UPDATE tasks SET description = '优化年终绩效评估流程，简化评估步骤，提高评估效率和质量。引入360度评估、校准会议等方法，确保评估结果公平公正。'
WHERE id = 'task-hr-nov-102';

UPDATE tasks SET description = '编制2026年度培训计划，基于组织战略和员工发展需求，规划全年培训项目。包括新员工培训、管理培训、专业技能培训等，合理配置培训资源。'
WHERE id = 'task-hr-nov-103';

UPDATE tasks SET description = '审批校园招聘Offer发放，审核候选人背景、面试评价、薪酬方案等信息。确定录用名单，批准Offer条款，控制招聘质量和成本。'
WHERE id = 'task-hr-nov-104';

UPDATE tasks SET description = '设计年度员工关怀计划，包括生日祝福、节日慰问、困难帮扶、家庭关怀等项目。建立常态化关怀机制，提升员工幸福感和归属感。'
WHERE id = 'task-hr-nov-105';

UPDATE tasks SET description = '讨论组织架构优化方案，评估现有架构的问题和改进空间。结合业务发展需要，提出架构调整建议，优化管理层级和汇报关系。'
WHERE id = 'task-hr-nov-106';

UPDATE tasks SET description = '回顾年度人才发展体系建设工作，总结人才选拔、培养、使用、保留等方面的成效。分析存在问题，提出改进措施，完善人才发展机制。'
WHERE id = 'task-hr-nov-107';

UPDATE tasks SET description = '编制2026年招聘预算，预测招聘需求和成本。包括招聘广告费、猎头费、差旅费、测评费等项目，合理规划招聘资源投入。'
WHERE id = 'task-hr-nov-108';

UPDATE tasks SET description = '分析员工离职率数据，识别离职高发部门、岗位、时期等。深入分析离职原因，提出针对性的保留措施，降低关键人才流失。'
WHERE id = 'task-hr-nov-109';

UPDATE tasks SET description = '编制年度HR工作总结材料，全面总结招聘、培训、绩效、薪酬、文化等工作成果。梳理亮点工作，分析问题不足，为年度汇报做准备。'
WHERE id = 'task-hr-nov-110';

UPDATE tasks SET description = '筹备和执行年度员工大会，包括会议策划、流程设计、节目编排、场地布置、奖品准备等。总结年度成绩，表彰先进，凝聚人心。'
WHERE id = 'task-hr-nov-111';

UPDATE tasks SET description = '推进第四季度人才盘点实施，组织各部门开展人才评估和盘点。识别高潜人才，发现能力短板，为人才发展和配置提供依据。'
WHERE id = 'task-hr-nov-112';

UPDATE tasks SET description = '组织HR系统上线培训，帮助员工和HR人员掌握新系统操作。编制培训教材，开展分批培训，提供操作指南和咨询支持。'
WHERE id = 'task-hr-nov-113';

UPDATE tasks SET description = '制定和审核年终奖发放方案，确定奖金总额、分配规则、计算方法等。平衡激励效果和成本控制，确保方案公平合理，激发员工积极性。'
WHERE id = 'task-hr-nov-114';

UPDATE tasks SET description = '开展新员工转正评估面谈，评估试用期工作表现、能力素质、团队融入等情况。与员工沟通职业规划，提供发展建议，决定是否转正。'
WHERE id = 'task-hr-nov-115';

UPDATE tasks SET description = '组织部门管理者领导力培训，提升管理者的领导能力和管理水平。课程涵盖战略思维、团队激励、变革管理、教练辅导等主题。'
WHERE id = 'task-hr-nov-116';

UPDATE tasks SET description = '开展薪酬福利满意度调研，了解员工对薪酬福利的感受和期望。分析薪酬竞争力和福利吸引力，为薪酬福利优化提供依据。'
WHERE id = 'task-hr-nov-117';

UPDATE tasks SET description = '开展校园招聘简历筛选和面试工作，评估候选人的专业能力、综合素质、发展潜力等。通过笔试、面试、测评等方式，选拔优秀应届生。'
WHERE id = 'task-hr-nov-118';

UPDATE tasks SET description = '启动企业文化宣传月活动，通过多种形式传播企业文化理念。组织文化故事分享、文化知识竞赛、文化实践活动等，增强文化认同。'
WHERE id = 'task-hr-nov-119';

UPDATE tasks SET description = '集中办理劳动合同续签工作，通知到期员工，准备合同文本，组织签署仪式。确保合同续签及时、规范，维护劳动关系稳定。'
WHERE id = 'task-hr-nov-120';

-- ========== 12月剩余任务 ==========

UPDATE tasks SET description = '开展核心人才年终面谈沟通，了解核心人才的工作感受、职业规划、发展需求等。倾听意见建议，解决实际问题，增强保留意愿。'
WHERE id = 'task-hr-dec-016';

SELECT '✅ 已为剩余22条HR任务补充详细描述！' as result;



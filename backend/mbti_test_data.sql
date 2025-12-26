-- MBTI测试数据插入脚本
-- 为测试和演示目的插入示例MBTI记录

USE enterprise_management;

-- 插入示例MBTI记录数据
INSERT INTO mbti_records (
    id, 
    user_id, 
    mbti_type, 
    test_scores, 
    personality_traits, 
    ai_analysis, 
    work_suggestions, 
    improvement_advice,
    personal_info,
    confidence_score,
    test_version
) VALUES 
-- 管理员INFP记录
(
    'mbti-001',
    'admin-001',
    'INFP',
    JSON_OBJECT(
        'I', 80,
        'N', 85,
        'F', 90,
        'P', 70,
        'total_score', 325
    ),
    JSON_OBJECT(
        'introversion', '内向型，喜欢深度思考和内省',
        'intuition', '直觉型，关注可能性和意义',
        'feeling', '情感型，重视价值观和和谐',
        'perceiving', '感知型，保持开放和灵活'
    ),
    JSON_OBJECT(
        'strengths', JSON_ARRAY('深度思考', '价值观驱动', '创造力', '同理心'),
        'weaknesses', JSON_ARRAY('过度理想化', '避免冲突', '完美主义'),
        'career_suitability', JSON_ARRAY('心理咨询', '写作编辑', '艺术设计', '社会服务'),
        'leadership_style', '服务型领导，注重团队价值观和成长'
    ),
    JSON_OBJECT(
        'work_environment', '适合安静、有意义的独立工作环境',
        'team_role', '价值观守护者和创意贡献者',
        'development_focus', JSON_ARRAY('现实感培养', '冲突处理', '时间管理'),
        'communication_style', '温和、深思熟虑，注重理解和共鸣'
    ),
    JSON_OBJECT(
        'improvement_areas', JSON_ARRAY('增强现实感', '学会处理冲突', '提高时间管理'),
        'learning_suggestions', JSON_ARRAY('学习项目管理', '培养批判性思维', '提升执行力'),
        'career_advice', '考虑从事需要深度思考和价值观驱动的工作'
    ),
    JSON_OBJECT(
        'full_name', '张三',
        'birth_date', '1990-05-15',
        'address', '北京市朝阳区',
        'phone', '13800138000',
        'email', 'zhangsan@example.com'
    ),
    0.88,
    'v1.0'
),

-- 创始人INTJ记录
(
    'mbti-002',
    'founder-001',
    'INTJ',
    JSON_OBJECT(
        'E', 25,
        'N', 85,
        'T', 80,
        'J', 90,
        'total_score', 280
    ),
    JSON_OBJECT(
        'extroversion', '内向型，喜欢独立思考',
        'intuition', '直觉型，善于战略规划',
        'thinking', '思维型，注重逻辑分析',
        'judging', '判断型，喜欢有序和计划'
    ),
    JSON_OBJECT(
        'strengths', JSON_ARRAY('战略思维', '独立性强', '逻辑分析', '执行力强'),
        'weaknesses', JSON_ARRAY('人际交往', '情感表达', '灵活性'),
        'career_suitability', JSON_ARRAY('战略规划', '技术研发', '管理咨询', '投资分析'),
        'leadership_style', '愿景型领导，注重长远规划'
    ),
    JSON_OBJECT(
        'work_environment', '适合独立、安静的工作环境',
        'team_role', '战略规划者和技术专家',
        'development_focus', JSON_ARRAY('人际沟通技能', '团队协作能力', '情感表达'),
        'communication_style', '理性、直接，注重事实和数据'
    ),
    JSON_OBJECT(
        'improvement_areas', JSON_ARRAY('提升人际交往能力', '增强情感表达', '提高灵活性'),
        'learning_suggestions', JSON_ARRAY('学习团队管理', '培养情商', '提升沟通技巧'),
        'career_advice', '适合担任技术领导或战略规划职位'
    ),
    JSON_OBJECT(
        'full_name', '李四',
        'birth_date', '1985-03-20',
        'address', '上海市浦东新区',
        'phone', '13900139000',
        'email', 'lisi@example.com'
    ),
    0.92,
    'v1.0'
),

-- 人事总监ESTJ记录
(
    'mbti-003',
    'hr_head',
    'ESTJ',
    JSON_OBJECT(
        'E', 85,
        'S', 80,
        'T', 75,
        'J', 90,
        'total_score', 330
    ),
    JSON_OBJECT(
        'extroversion', '外向型，善于领导和组织',
        'sensing', '感觉型，注重实际和细节',
        'thinking', '思维型，注重逻辑和效率',
        'judging', '判断型，喜欢有序和计划'
    ),
    JSON_OBJECT(
        'strengths', JSON_ARRAY('组织能力', '执行力强', '责任心强', '领导力'),
        'weaknesses', JSON_ARRAY('灵活性', '创新思维', '情感表达'),
        'career_suitability', JSON_ARRAY('管理岗位', '行政管理', '项目管理', '运营管理'),
        'leadership_style', '任务型领导，注重效率和结果'
    ),
    JSON_OBJECT(
        'work_environment', '适合结构化、目标导向的工作环境',
        'team_role', '组织者和执行者',
        'development_focus', JSON_ARRAY('创新思维', '情感表达', '灵活性'),
        'communication_style', '直接、高效，注重结果和效率'
    ),
    JSON_OBJECT(
        'improvement_areas', JSON_ARRAY('培养创新思维', '增强情感表达', '提高灵活性'),
        'learning_suggestions', JSON_ARRAY('学习创新方法', '培养情商', '提升适应性'),
        'career_advice', '适合担任管理岗位，发挥组织和执行能力'
    ),
    JSON_OBJECT(
        'full_name', '王五',
        'birth_date', '1988-07-10',
        'address', '广州市天河区',
        'phone', '13700137000',
        'email', 'wangwu@example.com'
    ),
    0.85,
    'v1.0'
),

-- 财务总监ISTJ记录
(
    'mbti-004',
    'finance_head',
    'ISTJ',
    JSON_OBJECT(
        'E', 20,
        'S', 85,
        'T', 80,
        'J', 90,
        'total_score', 275
    ),
    JSON_OBJECT(
        'extroversion', '内向型，喜欢独立工作',
        'sensing', '感觉型，注重事实和细节',
        'thinking', '思维型，注重逻辑和客观',
        'judging', '判断型，喜欢有序和计划'
    ),
    JSON_OBJECT(
        'strengths', JSON_ARRAY('责任心强', '逻辑思维', '执行力强', '稳定性'),
        'weaknesses', JSON_ARRAY('创新思维', '灵活性', '人际交往'),
        'career_suitability', JSON_ARRAY('财务管理', '审计', '法律', '工程'),
        'leadership_style', '任务型领导，注重效率和结果'
    ),
    JSON_OBJECT(
        'work_environment', '适合安静、有序的工作环境',
        'team_role', '执行者和监督者',
        'development_focus', JSON_ARRAY('创新思维', '人际沟通', '灵活性'),
        'communication_style', '直接、客观，注重事实'
    ),
    JSON_OBJECT(
        'improvement_areas', JSON_ARRAY('培养创新思维', '提升人际交往', '增强灵活性'),
        'learning_suggestions', JSON_ARRAY('学习创新方法', '培养沟通技巧', '提升适应能力'),
        'career_advice', '适合从事需要精确和责任心的工作'
    ),
    JSON_OBJECT(
        'full_name', '赵六',
        'birth_date', '1982-11-25',
        'address', '深圳市南山区',
        'phone', '13600136000',
        'email', 'zhaoliu@example.com'
    ),
    0.88,
    'v1.0'
),

-- 宣传总监ENFJ记录
(
    'mbti-005',
    'marketing_head',
    'ENFJ',
    JSON_OBJECT(
        'E', 85,
        'N', 80,
        'F', 90,
        'J', 75,
        'total_score', 330
    ),
    JSON_OBJECT(
        'extroversion', '外向型，善于社交和领导',
        'intuition', '直觉型，善于洞察他人',
        'feeling', '情感型，重视价值观和和谐',
        'judging', '判断型，喜欢有序和计划'
    ),
    JSON_OBJECT(
        'strengths', JSON_ARRAY('领导能力', '沟通技巧', '同理心', '组织能力'),
        'weaknesses', JSON_ARRAY('批判思维', '独立性', '客观性'),
        'career_suitability', JSON_ARRAY('人力资源管理', '教育培训', '心理咨询', '市场营销'),
        'leadership_style', '变革型领导，善于激励和启发他人'
    ),
    JSON_OBJECT(
        'work_environment', '适合开放、协作的工作环境',
        'team_role', '领导者和激励者',
        'development_focus', JSON_ARRAY('批判性思维', '独立性', '客观性'),
        'communication_style', '热情、有感染力，善于激励他人'
    ),
    JSON_OBJECT(
        'improvement_areas', JSON_ARRAY('培养批判性思维', '提高独立性', '增强客观性'),
        'learning_suggestions', JSON_ARRAY('学习数据分析', '培养独立思考', '提升客观判断'),
        'career_advice', '适合担任团队领导或人力资源相关职位'
    ),
    JSON_OBJECT(
        'full_name', '孙七',
        'birth_date', '1987-09-12',
        'address', '杭州市西湖区',
        'phone', '13500135000',
        'email', 'sunqi@example.com'
    ),
    0.90,
    'v1.0'
);

-- 创建MBTI统计视图
CREATE OR REPLACE VIEW mbti_statistics AS
SELECT 
    mbti_type,
    COUNT(*) as total_count,
    AVG(confidence_score) as avg_confidence,
    COUNT(DISTINCT user_id) as unique_users,
    MAX(test_date) as latest_test
FROM mbti_records 
WHERE is_active = TRUE 
GROUP BY mbti_type
ORDER BY total_count DESC;

-- 创建用户MBTI历史视图
CREATE OR REPLACE VIEW user_mbti_history AS
SELECT 
    mr.id,
    mr.user_id,
    u.name as user_name,
    u.position,
    d.name as department_name,
    mr.mbti_type,
    mr.test_date,
    mr.confidence_score,
    mr.created_at
FROM mbti_records mr
JOIN users u ON mr.user_id = u.id
LEFT JOIN departments d ON u.department_id = d.id
WHERE mr.is_active = TRUE
ORDER BY mr.test_date DESC;

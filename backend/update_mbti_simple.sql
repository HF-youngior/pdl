USE enterprise_management;

-- 删除现有的admin和hr_head的MBTI记录
DELETE FROM mbti_records WHERE user_id IN ('admin-001', 'dept-head-001');

-- 插入更新的admin-001 INFP记录
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
) VALUES (
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
);

-- 插入更新的hr_head ESTJ记录
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
) VALUES (
    'mbti-003',
    'dept-head-001',
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
);

-- 验证更新结果
SELECT 
    user_id,
    mbti_type,
    JSON_EXTRACT(test_scores, '$.I') as I_score,
    JSON_EXTRACT(test_scores, '$.E') as E_score,
    JSON_EXTRACT(test_scores, '$.S') as S_score,
    JSON_EXTRACT(test_scores, '$.N') as N_score,
    JSON_EXTRACT(test_scores, '$.T') as T_score,
    JSON_EXTRACT(test_scores, '$.F') as F_score,
    JSON_EXTRACT(test_scores, '$.J') as J_score,
    JSON_EXTRACT(test_scores, '$.P') as P_score
FROM mbti_records 
WHERE user_id IN ('admin-001', 'dept-head-001')
ORDER BY user_id;

-- MBTI记录表创建脚本
-- 用于存储用户的MBTI测试结果和AI分析建议

USE enterprise_management;

-- 创建MBTI记录表
CREATE TABLE IF NOT EXISTS mbti_records (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    test_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    mbti_type VARCHAR(4) NOT NULL,
    test_scores JSON NOT NULL COMMENT 'MBTI各维度得分详情',
    personality_traits JSON NOT NULL COMMENT '性格特质分析结果',
    ai_analysis JSON NOT NULL COMMENT 'AI智能分析结果',
    work_suggestions JSON NOT NULL COMMENT '工作建议和职业指导',
    improvement_advice JSON COMMENT '个人改进建议',
    personal_info JSON COMMENT '扩展个人信息（姓名、生日、地址等）',
    test_version VARCHAR(20) DEFAULT 'v1.0' COMMENT '测试版本',
    confidence_score DECIMAL(3,2) DEFAULT 0.00 COMMENT '测试可信度(0-1)',
    is_active BOOLEAN DEFAULT TRUE COMMENT '记录是否有效',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    
    -- 外键约束
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    
    -- 索引优化
    INDEX idx_user_id (user_id),
    INDEX idx_test_date (test_date),
    INDEX idx_mbti_type (mbti_type),
    INDEX idx_is_active (is_active),
    INDEX idx_user_test_date (user_id, test_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci 
COMMENT='MBTI测试记录表，存储用户性格测试结果和AI分析建议';

-- 插入示例数据
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
    confidence_score
) VALUES (
    'mbti-001',
    'admin-001',
    'ENFP',
    JSON_OBJECT(
        'E', 75,
        'N', 80,
        'F', 70,
        'P', 65,
        'total_score', 290
    ),
    JSON_OBJECT(
        'extroversion', '外向型，善于社交和沟通',
        'intuition', '直觉型，喜欢探索新可能性',
        'feeling', '情感型，重视人际关系和价值观',
        'perceiving', '感知型，灵活适应环境变化'
    ),
    JSON_OBJECT(
        'strengths', JSON_ARRAY('创新思维', '团队合作', '沟通能力', '适应性强'),
        'weaknesses', JSON_ARRAY('细节处理', '时间管理', '决策果断性'),
        'career_suitability', JSON_ARRAY('市场营销', '人力资源', '创意设计', '教育培训'),
        'leadership_style', '民主型领导，善于激励团队'
    ),
    JSON_OBJECT(
        'work_environment', '适合开放、灵活的工作环境',
        'team_role', '团队协调者和创新推动者',
        'development_focus', JSON_ARRAY('时间管理技能', '决策能力', '细节关注'),
        'communication_style', '热情、富有感染力，善于激励他人'
    ),
    JSON_OBJECT(
        'improvement_areas', JSON_ARRAY('提高专注力', '加强时间规划', '培养决策能力'),
        'learning_suggestions', JSON_ARRAY('学习项目管理', '培养批判性思维', '提升执行力'),
        'career_advice', '考虑从事需要创意和人际交往的工作'
    ),
    JSON_OBJECT(
        'full_name', '张三',
        'birth_date', '1990-05-15',
        'address', '北京市朝阳区',
        'phone', '13800138000',
        'email', 'zhangsan@example.com'
    ),
    0.85
);

-- 创建MBTI记录统计视图
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

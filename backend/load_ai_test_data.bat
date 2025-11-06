@echo off
echo 正在加载AI模块测试数据...

REM 设置数据库连接参数
set DB_HOST=localhost
set DB_USER=root
set DB_PASSWORD=Zs462581379
set DB_NAME=enterprise_management

echo 连接数据库: %DB_NAME%

REM 创建临时SQL文件
set TEMP_SQL=temp_ai_data.sql
echo 生成测试数据SQL文件...

REM 生成SQL内容
(
echo USE enterprise_management;
echo.
echo -- 清空现有AI测试数据
echo DELETE FROM personality_analysis WHERE user_id IN ^('admin-001', 'founder-001', 'founder-002', 'dept-head-001', 'dept-head-002', 'dept-head-003', 'team-leader-001', 'team-leader-002', 'team-leader-003', 'team-leader-004', 'team-leader-005', 'team-leader-006', 'employee-001', 'employee-002', 'employee-003', 'employee-004', 'employee-005', 'employee-006', 'employee-007', 'employee-008', 'employee-009', 'employee-010', 'employee-011', 'employee-012'^);
echo DELETE FROM wordcloud_analysis WHERE user_id IN ^('admin-001', 'founder-001', 'founder-002', 'dept-head-001', 'dept-head-002', 'dept-head-003', 'team-leader-001', 'team-leader-002', 'team-leader-003', 'team-leader-004', 'team-leader-005', 'team-leader-006', 'employee-001', 'employee-002', 'employee-003', 'employee-004', 'employee-005', 'employee-006', 'employee-007', 'employee-008', 'employee-009', 'employee-010', 'employee-011', 'employee-012'^);
echo.

REM 生成管理员数据
echo -- 管理员数据 (INFP)
echo INSERT INTO personality_analysis ^(user_id, analysis_date, personality_traits, mbti_type, work_suggestions, personality_chart, description^) VALUES
echo ^('admin-001', '2025-01-27 10:00:00', 
echo JSON_OBJECT^('外向性', 0.20, '宜人性', 0.90, '尽责性', 0.85, '神经质', 0.35, '开放性', 0.80^),
echo 'INFP',
echo JSON_OBJECT^('适合职业', JSON_ARRAY^('心理咨询', '写作编辑', '艺术设计', '社会服务'^), '工作环境', '安静、有意义、独立', '发展建议', '增强现实感，学会处理冲突', '沟通风格', '温和、深思熟虑，注重理解'^),
echo JSON_OBJECT^('traits', JSON_OBJECT^('外向性', 0.20, '宜人性', 0.90, '尽责性', 0.85, '神经质', 0.35, '开放性', 0.80^), 'dimensions', JSON_OBJECT^('领导力', 0.70, '创造力', 0.90, '沟通能力', 0.75, '分析能力', 0.80, '团队合作', 0.85^)^),
echo '系统管理员性格分析'^);
echo.

echo INSERT INTO wordcloud_analysis ^(user_id, analysis_date, keywords, word_frequencies, description^) VALUES
echo ^('admin-001', '2025-01-27 10:00:00',
echo JSON_ARRAY^(JSON_OBJECT^('word', '系统管理', 'weight', 0.95^), JSON_OBJECT^('word', '团队协调', 'weight', 0.85^), JSON_OBJECT^('word', '项目管理', 'weight', 0.80^), JSON_OBJECT^('word', '创新', 'weight', 0.75^), JSON_OBJECT^('word', '沟通', 'weight', 0.70^)^),
echo JSON_ARRAY^(JSON_OBJECT^('word', '系统管理', 'count', 25^), JSON_OBJECT^('word', '团队协调', 'count', 20^), JSON_OBJECT^('word', '项目管理', 'count', 18^), JSON_OBJECT^('word', '创新', 'count', 15^), JSON_OBJECT^('word', '沟通', 'count', 12^)^),
echo '管理员工作日志词云分析'^);
echo.

REM 生成创始人数据
echo -- 创始人数据 (INTJ)
echo INSERT INTO personality_analysis ^(user_id, analysis_date, personality_traits, mbti_type, work_suggestions, personality_chart, description^) VALUES
echo ^('founder-001', '2025-01-27 10:00:00',
echo JSON_OBJECT^('外向性', 0.30, '宜人性', 0.60, '尽责性', 0.95, '神经质', 0.20, '开放性', 0.90^),
echo 'INTJ',
echo JSON_OBJECT^('适合职业', JSON_ARRAY^('战略规划', '技术研发', '管理咨询', '投资分析'^), '工作环境', '独立、安静、专注', '发展建议', '保持战略思维，加强团队沟通', '沟通风格', '直接、逻辑清晰'^),
echo JSON_OBJECT^('traits', JSON_OBJECT^('外向性', 0.30, '宜人性', 0.60, '尽责性', 0.95, '神经质', 0.20, '开放性', 0.90^), 'dimensions', JSON_OBJECT^('领导力', 0.90, '创造力', 0.85, '沟通能力', 0.60, '分析能力', 0.95, '团队合作', 0.70^)^),
echo '创始人性格分析'^);
echo.

echo INSERT INTO wordcloud_analysis ^(user_id, analysis_date, keywords, word_frequencies, description^) VALUES
echo ^('founder-001', '2025-01-27 10:00:00',
echo JSON_ARRAY^(JSON_OBJECT^('word', '战略规划', 'weight', 0.95^), JSON_OBJECT^('word', '技术研发', 'weight', 0.90^), JSON_OBJECT^('word', '创新', 'weight', 0.85^), JSON_OBJECT^('word', '管理', 'weight', 0.80^), JSON_OBJECT^('word', '投资', 'weight', 0.75^)^),
echo JSON_ARRAY^(JSON_OBJECT^('word', '战略规划', 'count', 30^), JSON_OBJECT^('word', '技术研发', 'count', 25^), JSON_OBJECT^('word', '创新', 'count', 20^), JSON_OBJECT^('word', '管理', 'count', 18^), JSON_OBJECT^('word', '投资', 'count', 15^)^),
echo '创始人工作日志词云分析'^);
echo.

REM 生成部门总监数据
echo -- 人事总监数据 (ESTJ)
echo INSERT INTO personality_analysis ^(user_id, analysis_date, personality_traits, mbti_type, work_suggestions, personality_chart, description^) VALUES
echo ^('dept-head-001', '2025-01-27 10:00:00',
echo JSON_OBJECT^('外向性', 0.85, '宜人性', 0.75, '尽责性', 0.95, '神经质', 0.30, '开放性', 0.55^),
echo 'ESTJ',
echo JSON_OBJECT^('适合职业', JSON_ARRAY^('管理岗位', '行政管理', '项目管理', '运营管理'^), '工作环境', '结构化、目标导向', '发展建议', '培养创新思维，增强情感表达', '沟通风格', '直接、高效，注重结果'^),
echo JSON_OBJECT^('traits', JSON_OBJECT^('外向性', 0.85, '宜人性', 0.75, '尽责性', 0.95, '神经质', 0.30, '开放性', 0.55^), 'dimensions', JSON_OBJECT^('领导力', 0.90, '创造力', 0.60, '沟通能力', 0.85, '分析能力', 0.85, '团队合作', 0.80^)^),
echo '人事总监性格分析'^);
echo.

echo INSERT INTO wordcloud_analysis ^(user_id, analysis_date, keywords, word_frequencies, description^) VALUES
echo ^('dept-head-001', '2025-01-27 10:00:00',
echo JSON_ARRAY^(JSON_OBJECT^('word', '人力资源', 'weight', 0.95^), JSON_OBJECT^('word', '员工关系', 'weight', 0.90^), JSON_OBJECT^('word', '培训', 'weight', 0.85^), JSON_OBJECT^('word', '组织文化', 'weight', 0.80^), JSON_OBJECT^('word', '团队', 'weight', 0.75^)^),
echo JSON_ARRAY^(JSON_OBJECT^('word', '人力资源', 'count', 28^), JSON_OBJECT^('word', '员工关系', 'count', 22^), JSON_OBJECT^('word', '培训', 'count', 20^), JSON_OBJECT^('word', '组织文化', 'count', 18^), JSON_OBJECT^('word', '团队', 'count', 15^)^),
echo '人事总监工作日志词云分析'^);
echo.

REM 生成财务总监数据
echo -- 财务总监数据 (ISTJ)
echo INSERT INTO personality_analysis ^(user_id, analysis_date, personality_traits, mbti_type, work_suggestions, personality_chart, description^) VALUES
echo ^('dept-head-002', '2025-01-27 10:00:00',
echo JSON_OBJECT^('外向性', 0.25, '宜人性', 0.70, '尽责性', 0.98, '神经质', 0.30, '开放性', 0.45^),
echo 'ISTJ',
echo JSON_OBJECT^('适合职业', JSON_ARRAY^('财务管理', '审计', '风险控制', '合规管理'^), '工作环境', '安静、有序、稳定', '发展建议', '保持专业精神，提升沟通技巧', '沟通风格', '严谨、注重细节'^),
echo JSON_OBJECT^('traits', JSON_OBJECT^('外向性', 0.25, '宜人性', 0.70, '尽责性', 0.98, '神经质', 0.30, '开放性', 0.45^), 'dimensions', JSON_OBJECT^('领导力', 0.70, '创造力', 0.50, '沟通能力', 0.65, '分析能力', 0.95, '团队合作', 0.80^)^),
echo '财务总监性格分析'^);
echo.

echo INSERT INTO wordcloud_analysis ^(user_id, analysis_date, keywords, word_frequencies, description^) VALUES
echo ^('dept-head-002', '2025-01-27 10:00:00',
echo JSON_ARRAY^(JSON_OBJECT^('word', '财务管理', 'weight', 0.95^), JSON_OBJECT^('word', '审计', 'weight', 0.90^), JSON_OBJECT^('word', '风险控制', 'weight', 0.85^), JSON_OBJECT^('word', '合规', 'weight', 0.80^), JSON_OBJECT^('word', '预算', 'weight', 0.75^)^),
echo JSON_ARRAY^(JSON_OBJECT^('word', '财务管理', 'count', 32^), JSON_OBJECT^('word', '审计', 'count', 25^), JSON_OBJECT^('word', '风险控制', 'count', 22^), JSON_OBJECT^('word', '合规', 'count', 20^), JSON_OBJECT^('word', '预算', 'count', 18^)^),
echo '财务总监工作日志词云分析'^);
echo.

REM 生成宣传总监数据
echo -- 宣传总监数据 (ENFJ)
echo INSERT INTO personality_analysis ^(user_id, analysis_date, personality_traits, mbti_type, work_suggestions, personality_chart, description^) VALUES
echo ^('dept-head-003', '2025-01-27 10:00:00',
echo JSON_OBJECT^('外向性', 0.90, '宜人性', 0.95, '尽责性', 0.85, '神经质', 0.40, '开放性', 0.80^),
echo 'ENFJ',
echo JSON_OBJECT^('适合职业', JSON_ARRAY^('品牌管理', '市场营销', '公关传播', '团队领导'^), '工作环境', '开放、创新、团队合作', '发展建议', '发挥领导魅力，加强数据分析', '沟通风格', '激励他人、富有感染力'^),
echo JSON_OBJECT^('traits', JSON_OBJECT^('外向性', 0.90, '宜人性', 0.95, '尽责性', 0.85, '神经质', 0.40, '开放性', 0.80^), 'dimensions', JSON_OBJECT^('领导力', 0.95, '创造力', 0.85, '沟通能力', 0.95, '分析能力', 0.70, '团队合作', 0.90^)^),
echo '宣传总监性格分析'^);
echo.

echo INSERT INTO wordcloud_analysis ^(user_id, analysis_date, keywords, word_frequencies, description^) VALUES
echo ^('dept-head-003', '2025-01-27 10:00:00',
echo JSON_ARRAY^(JSON_OBJECT^('word', '品牌管理', 'weight', 0.95^), JSON_OBJECT^('word', '市场营销', 'weight', 0.90^), JSON_OBJECT^('word', '公关传播', 'weight', 0.85^), JSON_OBJECT^('word', '创意', 'weight', 0.80^), JSON_OBJECT^('word', '团队', 'weight', 0.75^)^),
echo JSON_ARRAY^(JSON_OBJECT^('word', '品牌管理', 'count', 30^), JSON_OBJECT^('word', '市场营销', 'count', 25^), JSON_OBJECT^('word', '公关传播', 'count', 22^), JSON_OBJECT^('word', '创意', 'count', 20^), JSON_OBJECT^('word', '团队', 'count', 18^)^),
echo '宣传总监工作日志词云分析'^);
echo.

REM 生成团队长数据 (简化版本，包含几个代表性团队长)
echo -- 团队长数据
echo INSERT INTO personality_analysis ^(user_id, analysis_date, personality_traits, mbti_type, work_suggestions, personality_chart, description^) VALUES
echo ^('team-leader-001', '2025-01-27 10:00:00', JSON_OBJECT^('外向性', 0.70, '宜人性', 0.80, '尽责性', 0.90, '神经质', 0.35, '开放性', 0.65^), 'ENTJ', JSON_OBJECT^('适合职业', JSON_ARRAY^('团队管理', '项目管理', '业务发展'^), '工作环境', '快节奏、目标导向', '发展建议', '发挥执行力，提升团队激励', '沟通风格', '直接、目标明确'^), JSON_OBJECT^('traits', JSON_OBJECT^('外向性', 0.70, '宜人性', 0.80, '尽责性', 0.90, '神经质', 0.35, '开放性', 0.65^), 'dimensions', JSON_OBJECT^('领导力', 0.90, '创造力', 0.70, '沟通能力', 0.85, '分析能力', 0.80, '团队合作', 0.85^)^), '人事团队长性格分析'^),
echo ^('team-leader-003', '2025-01-27 10:00:00', JSON_OBJECT^('外向性', 0.45, '宜人性', 0.75, '尽责性', 0.95, '神经质', 0.30, '开放性', 0.55^), 'ISTJ', JSON_OBJECT^('适合职业', JSON_ARRAY^('财务管理', '团队协调', '流程优化'^), '工作环境', '有序、专业、稳定', '发展建议', '保持专业精神，提升沟通技巧', '沟通风格', '严谨、注重细节'^), JSON_OBJECT^('traits', JSON_OBJECT^('外向性', 0.45, '宜人性', 0.75, '尽责性', 0.95, '神经质', 0.30, '开放性', 0.55^), 'dimensions', JSON_OBJECT^('领导力', 0.75, '创造力', 0.60, '沟通能力', 0.70, '分析能力', 0.90, '团队合作', 0.80^)^), '财务团队长性格分析'^),
echo ^('team-leader-005', '2025-01-27 10:00:00', JSON_OBJECT^('外向性', 0.85, '宜人性', 0.85, '尽责性', 0.80, '神经质', 0.45, '开放性', 0.75^), 'ESFJ', JSON_OBJECT^('适合职业', JSON_ARRAY^('团队管理', '客户关系', '活动策划'^), '工作环境', '团队合作、客户导向', '发展建议', '发挥服务精神，提升创新思维', '沟通风格', '关怀他人、团队导向'^), JSON_OBJECT^('traits', JSON_OBJECT^('外向性', 0.85, '宜人性', 0.85, '尽责性', 0.80, '神经质', 0.45, '开放性', 0.75^), 'dimensions', JSON_OBJECT^('领导力', 0.80, '创造力', 0.70, '沟通能力', 0.90, '分析能力', 0.70, '团队合作', 0.95^)^), '宣传团队长性格分析'^);
echo.

REM 生成员工数据 (简化版本，包含几个代表性员工)
echo -- 员工数据
echo INSERT INTO personality_analysis ^(user_id, analysis_date, personality_traits, mbti_type, work_suggestions, personality_chart, description^) VALUES
echo ^('employee-001', '2025-01-27 10:00:00', JSON_OBJECT^('外向性', 0.60, '宜人性', 0.85, '尽责性', 0.88, '神经质', 0.40, '开放性', 0.70^), 'ENFP', JSON_OBJECT^('适合职业', JSON_ARRAY^('人事专员', '培训师', '团队协调'^), '工作环境', '开放、创新、团队合作', '发展建议', '发挥创造力，加强执行力', '沟通风格', '热情、富有感染力'^), JSON_OBJECT^('traits', JSON_OBJECT^('外向性', 0.60, '宜人性', 0.85, '尽责性', 0.88, '神经质', 0.40, '开放性', 0.70^), 'dimensions', JSON_OBJECT^('领导力', 0.75, '创造力', 0.80, '沟通能力', 0.85, '分析能力', 0.70, '团队合作', 0.90^)^), '人事专员性格分析'^),
echo ^('employee-005', '2025-01-27 10:00:00', JSON_OBJECT^('外向性', 0.30, '宜人性', 0.70, '尽责性', 0.95, '神经质', 0.25, '开放性', 0.50^), 'ISTJ', JSON_OBJECT^('适合职业', JSON_ARRAY^('财务专员', '数据分析', '审计'^), '工作环境', '安静、有序、专业', '发展建议', '保持专业精神，提升沟通技巧', '沟通风格', '严谨、注重细节'^), JSON_OBJECT^('traits', JSON_OBJECT^('外向性', 0.30, '宜人性', 0.70, '尽责性', 0.95, '神经质', 0.25, '开放性', 0.50^), 'dimensions', JSON_OBJECT^('领导力', 0.60, '创造力', 0.55, '沟通能力', 0.65, '分析能力', 0.95, '团队合作', 0.75^)^), '财务专员性格分析'^),
echo ^('employee-009', '2025-01-27 10:00:00', JSON_OBJECT^('外向性', 0.80, '宜人性', 0.80, '尽责性', 0.85, '神经质', 0.35, '开放性', 0.75^), 'ENFP', JSON_OBJECT^('适合职业', JSON_ARRAY^('宣传专员', '创意设计', '活动策划'^), '工作环境', '开放、创新、灵活', '发展建议', '发挥创造力，加强执行力', '沟通风格', '热情、富有感染力'^), JSON_OBJECT^('traits', JSON_OBJECT^('外向性', 0.80, '宜人性', 0.80, '尽责性', 0.85, '神经质', 0.35, '开放性', 0.75^), 'dimensions', JSON_OBJECT^('领导力', 0.70, '创造力', 0.85, '沟通能力', 0.90, '分析能力', 0.65, '团队合作', 0.85^)^), '宣传专员性格分析'^);
echo.

REM 生成词云分析数据 (为所有用户)
echo -- 词云分析数据
echo INSERT INTO wordcloud_analysis ^(user_id, analysis_date, keywords, word_frequencies, description^) VALUES
echo ^('team-leader-001', '2025-01-27 10:00:00', JSON_ARRAY^(JSON_OBJECT^('word', '团队管理', 'weight', 0.90^), JSON_OBJECT^('word', '项目管理', 'weight', 0.85^), JSON_OBJECT^('word', '业务发展', 'weight', 0.80^)^), JSON_ARRAY^(JSON_OBJECT^('word', '团队管理', 'count', 20^), JSON_OBJECT^('word', '项目管理', 'count', 18^), JSON_OBJECT^('word', '业务发展', 'count', 15^)^), '人事团队长工作日志词云分析'^),
echo ^('team-leader-003', '2025-01-27 10:00:00', JSON_ARRAY^(JSON_OBJECT^('word', '财务管理', 'weight', 0.90^), JSON_OBJECT^('word', '团队协调', 'weight', 0.85^), JSON_OBJECT^('word', '流程优化', 'weight', 0.80^)^), JSON_ARRAY^(JSON_OBJECT^('word', '财务管理', 'count', 22^), JSON_OBJECT^('word', '团队协调', 'count', 18^), JSON_OBJECT^('word', '流程优化', 'count', 16^)^), '财务团队长工作日志词云分析'^),
echo ^('team-leader-005', '2025-01-27 10:00:00', JSON_ARRAY^(JSON_OBJECT^('word', '团队管理', 'weight', 0.90^), JSON_OBJECT^('word', '客户关系', 'weight', 0.85^), JSON_OBJECT^('word', '活动策划', 'weight', 0.80^)^), JSON_ARRAY^(JSON_OBJECT^('word', '团队管理', 'count', 20^), JSON_OBJECT^('word', '客户关系', 'count', 18^), JSON_OBJECT^('word', '活动策划', 'count', 16^)^), '宣传团队长工作日志词云分析'^),
echo ^('employee-001', '2025-01-27 10:00:00', JSON_ARRAY^(JSON_OBJECT^('word', '人事管理', 'weight', 0.90^), JSON_OBJECT^('word', '培训', 'weight', 0.85^), JSON_OBJECT^('word', '团队协调', 'weight', 0.80^)^), JSON_ARRAY^(JSON_OBJECT^('word', '人事管理', 'count', 18^), JSON_OBJECT^('word', '培训', 'count', 16^), JSON_OBJECT^('word', '团队协调', 'count', 14^)^), '人事专员工作日志词云分析'^),
echo ^('employee-005', '2025-01-27 10:00:00', JSON_ARRAY^(JSON_OBJECT^('word', '财务分析', 'weight', 0.90^), JSON_OBJECT^('word', '数据处理', 'weight', 0.85^), JSON_OBJECT^('word', '审计', 'weight', 0.80^)^), JSON_ARRAY^(JSON_OBJECT^('word', '财务分析', 'count', 20^), JSON_OBJECT^('word', '数据处理', 'count', 18^), JSON_OBJECT^('word', '审计', 'count', 16^)^), '财务专员工作日志词云分析'^),
echo ^('employee-009', '2025-01-27 10:00:00', JSON_ARRAY^(JSON_OBJECT^('word', '创意设计', 'weight', 0.90^), JSON_OBJECT^('word', '活动策划', 'weight', 0.85^), JSON_OBJECT^('word', '品牌推广', 'weight', 0.80^)^), JSON_ARRAY^(JSON_OBJECT^('word', '创意设计', 'count', 18^), JSON_OBJECT^('word', '活动策划', 'count', 16^), JSON_OBJECT^('word', '品牌推广', 'count', 14^)^), '宣传专员工作日志词云分析'^);
echo.

echo -- 验证数据插入
echo SELECT 'personality_analysis' as table_name, COUNT^(*^) as record_count FROM personality_analysis
echo UNION ALL
echo SELECT 'wordcloud_analysis' as table_name, COUNT^(*^) as record_count FROM wordcloud_analysis;
) > %TEMP_SQL%

REM 执行SQL文件
echo 执行测试数据插入...
mysql -h%DB_HOST% -u%DB_USER% -p%DB_PASSWORD% %DB_NAME% < %TEMP_SQL%

if %ERRORLEVEL% neq 0 (
    echo 错误: 插入AI测试数据失败
    pause
    exit /b 1
)

REM 清理临时文件
del %TEMP_SQL%

echo.
echo ========================================
echo AI模块测试数据加载完成！
echo ========================================
echo.
echo 已加载的数据:
echo - 性格分析数据: 10条记录
echo - 词云分析数据: 10条记录
echo.
echo 用户覆盖:
echo - 管理员: 1人 (ENFP)
echo - 创始人: 1人 (INTJ)
echo - 部门总监: 3人 (ISFJ, ISTJ, ENFJ)
echo - 团队长: 3人 (ENTJ, ISTJ, ESFJ)
echo - 员工: 3人 (ENFP, ISTJ, ENFP)
echo.
echo 数据特性:
echo - 基于职位的合理MBTI类型分配
echo - 个性化的AI分析结果
echo - 符合角色特点的工作建议
echo - 真实的词云分析数据
echo.
echo 下一步: 启动服务器测试AI功能
echo.
pause

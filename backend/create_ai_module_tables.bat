@echo off
echo 正在创建AI模块相关数据库表...

REM 设置数据库连接参数
set DB_HOST=rm-2ze22f1xm8vvw4m44to.mysql.rds.aliyuncs.com
set DB_USER=pdl
set DB_PASSWORD=Pdl123456
set DB_NAME=enterprise_management

echo 连接数据库: %DB_NAME%

REM 创建词云分析表
echo 创建词云分析表 (wordcloud_analysis)...
mysql -h%DB_HOST% -u%DB_USER% -p%DB_PASSWORD% %DB_NAME% -e "
CREATE TABLE IF NOT EXISTS wordcloud_analysis (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL,
  analysis_date TIMESTAMP NOT NULL,
  keywords JSON NOT NULL COMMENT '关键词列表',
  word_frequencies JSON NOT NULL COMMENT '词频统计',
  description VARCHAR(500) COMMENT '分析描述',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user_id (user_id),
  INDEX idx_analysis_date (analysis_date),
  INDEX idx_user_analysis_date (user_id, analysis_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='词云分析表，存储用户日志的词云分析结果';
"

if %ERRORLEVEL% neq 0 (
    echo 错误: 创建词云分析表失败
    pause
    exit /b 1
)

REM 创建性格分析表
echo 创建性格分析表 (personality_analysis)...
mysql -h%DB_HOST% -u%DB_USER% -p%DB_PASSWORD% %DB_NAME% -e "
CREATE TABLE IF NOT EXISTS personality_analysis (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id VARCHAR(36) NOT NULL,
  analysis_date TIMESTAMP NOT NULL,
  personality_traits JSON NOT NULL COMMENT '性格特质分析结果',
  mbti_type VARCHAR(4) NOT NULL COMMENT 'MBTI类型',
  work_suggestions JSON NOT NULL COMMENT '工作建议',
  personality_chart JSON NOT NULL COMMENT '性格图表数据',
  ai_analysis_text TEXT COMMENT 'DeepSeek API返回的原始分析文本',
  description VARCHAR(500) COMMENT '分析描述',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user_id (user_id),
  INDEX idx_analysis_date (analysis_date),
  INDEX idx_mbti_type (mbti_type),
  INDEX idx_user_analysis_date (user_id, analysis_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='性格分析表，存储AI性格分析结果';
"

if %ERRORLEVEL% neq 0 (
    echo 错误: 创建性格分析表失败
    pause
    exit /b 1
)

REM 验证表创建
echo 验证表创建结果...
mysql -h%DB_HOST% -u%DB_USER% -p%DB_PASSWORD% %DB_NAME% -e "
SHOW TABLES LIKE '%analysis%';
"

echo.
echo ========================================
echo AI模块数据库表创建完成！
echo ========================================
echo.
echo 已创建的表:
echo - wordcloud_analysis (词云分析表)
echo - personality_analysis (性格分析表)
echo.
echo 表结构特性:
echo - 支持JSON数据存储
echo - 完整的外键约束
echo - 优化的索引设计
echo - UTF8MB4字符集支持
echo.
echo 下一步: 运行 load_ai_test_data.bat 加载测试数据
echo.
pause

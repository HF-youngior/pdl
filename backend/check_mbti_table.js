// 检查MBTI表是否存在
const mysql = require('mysql2/promise');

async function checkMbtiTable() {
  let connection;
  
  try {
    console.log('🔍 检查MBTI表...\n');
    
    // 连接数据库
    connection = await mysql.createConnection({
      host: process.env.DB_HOST || 'localhost',
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || '23301144',
      database: process.env.DB_NAME || 'enterprise_management'
    });
    
    console.log('✅ 数据库连接成功');
    
    // 检查表是否存在
    const [tables] = await connection.execute(
      "SHOW TABLES LIKE 'mbti_records'"
    );
    
    if (tables.length === 0) {
      console.log('❌ mbti_records表不存在');
      console.log('📝 创建表...');
      
      // 创建表
      await connection.execute(`
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
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
          INDEX idx_user_id (user_id),
          INDEX idx_test_date (test_date),
          INDEX idx_mbti_type (mbti_type),
          INDEX idx_is_active (is_active),
          INDEX idx_user_test_date (user_id, test_date)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='MBTI测试记录表，存储用户性格测试结果和AI分析建议'
      `);
      
      console.log('✅ mbti_records表创建成功');
    } else {
      console.log('✅ mbti_records表已存在');
    }
    
    // 检查表结构
    const [columns] = await connection.execute('DESCRIBE mbti_records');
    console.log('\n📋 表结构:');
    columns.forEach(col => {
      console.log(`  ${col.Field}: ${col.Type} ${col.Null === 'NO' ? 'NOT NULL' : 'NULL'}`);
    });
    
    // 检查是否有数据
    const [rows] = await connection.execute('SELECT COUNT(*) as count FROM mbti_records');
    console.log(`\n📊 表中记录数: ${rows[0].count}`);
    
  } catch (error) {
    console.error('❌ 检查失败:', error.message);
    console.error('错误堆栈:', error.stack);
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

checkMbtiTable();

/**
 * 删除2025年12月24日和25日的签到记录
 * 同时恢复相关积分和积分流水
 * 
 * 使用方法：
 * node delete_checkin_2025_12_24_25.js
 */

const mysql = require('mysql2/promise');
require('dotenv').config();

async function deleteCheckinRecords() {
  let connection;
  
  try {
    // 创建数据库连接
    connection = await mysql.createConnection({
      host: process.env.DB_HOST || 'localhost',
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || '',
      database: process.env.DB_NAME || 'enterprise_management',
      multipleStatements: true
    });

    console.log('✅ 数据库连接成功');
    console.log('========================================');
    console.log('开始删除2025-12-24和2025-12-25的签到记录');
    console.log('========================================\n');

    // 开始事务
    await connection.beginTransaction();

    // 1. 查找要删除的签到记录
    console.log('📋 查找要删除的签到记录...');
    const [checkinRecords] = await connection.execute(
      `SELECT 
        cr.id as checkin_id,
        cr.user_id,
        u.name as user_name,
        cr.checkin_date,
        cr.points_earned,
        cr.created_at
      FROM checkin_records cr
      JOIN users u ON cr.user_id = u.id
      WHERE cr.checkin_date IN ('2025-12-24', '2025-12-25')
      ORDER BY cr.checkin_date, u.name`
    );

    if (checkinRecords.length === 0) {
      console.log('ℹ️  没有找到2025-12-24和2025-12-25的签到记录');
      await connection.rollback();
      return;
    }

    console.log(`找到 ${checkinRecords.length} 条签到记录：`);
    checkinRecords.forEach((record, index) => {
      console.log(`  ${index + 1}. ${record.user_name} - ${record.checkin_date} - ${record.points_earned}积分`);
    });
    console.log('');

    // 2. 恢复用户积分
    console.log('💰 恢复用户积分...');
    const [updateResult] = await connection.execute(
      `UPDATE users u
      SET points = GREATEST(COALESCE(points, 0) - (
        SELECT COALESCE(SUM(cr.points_earned), 0)
        FROM checkin_records cr
        WHERE cr.user_id = u.id
        AND cr.checkin_date IN ('2025-12-24', '2025-12-25')
      ), 0)
      WHERE EXISTS (
        SELECT 1
        FROM checkin_records cr
        WHERE cr.user_id = u.id
        AND cr.checkin_date IN ('2025-12-24', '2025-12-25')
      )`
    );
    console.log(`✅ 已更新 ${updateResult.affectedRows} 个用户的积分\n`);

    // 3. 删除相关的积分流水记录
    console.log('📝 删除相关的积分流水记录...');
    const [deleteTransactions] = await connection.execute(
      `DELETE FROM points_transactions
      WHERE type = 'earn'
      AND description = '每日签到'
      AND related_id IN (
        SELECT id FROM checkin_records
        WHERE checkin_date IN ('2025-12-24', '2025-12-25')
      )`
    );
    console.log(`✅ 已删除 ${deleteTransactions.affectedRows} 条积分流水记录\n`);

    // 4. 删除签到记录
    console.log('🗑️  删除签到记录...');
    const [deleteResult] = await connection.execute(
      `DELETE FROM checkin_records
      WHERE checkin_date IN ('2025-12-24', '2025-12-25')`
    );
    console.log(`✅ 已删除 ${deleteResult.affectedRows} 条签到记录\n`);

    // 提交事务
    await connection.commit();
    console.log('========================================');
    console.log('✅ 删除完成！');
    console.log('========================================');
    console.log(`总共删除了 ${deleteResult.affectedRows} 条签到记录`);
    console.log(`恢复了 ${updateResult.affectedRows} 个用户的积分`);
    console.log(`删除了 ${deleteTransactions.affectedRows} 条积分流水记录\n`);

    // 验证删除结果
    const [verifyResult] = await connection.execute(
      `SELECT COUNT(*) as count
      FROM checkin_records
      WHERE checkin_date IN ('2025-12-24', '2025-12-25')`
    );
    
    if (verifyResult[0].count === 0) {
      console.log('✅ 验证通过：2025-12-24和2025-12-25的签到记录已全部删除');
    } else {
      console.log(`⚠️  警告：仍有 ${verifyResult[0].count} 条记录未删除`);
    }

  } catch (error) {
    if (connection) {
      await connection.rollback();
    }
    console.error('❌ 删除失败:', error.message);
    console.error(error);
    process.exit(1);
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

// 执行删除操作
deleteCheckinRecords();


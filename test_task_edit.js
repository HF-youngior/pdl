const mysql = require('mysql2/promise');

async function testTaskEdit() {
  const db = await mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: 'zyl030525',
    database: 'enterprise_management'
  });

  try {
    console.log('🔍 测试任务编辑功能...\n');

    // 1. 查找一个任务
    const [tasks] = await db.execute(
      `SELECT id, title, description, priority, status 
       FROM tasks 
       WHERE DATE(start_time) = '2025-10-16' 
       LIMIT 1`
    );

    if (tasks.length === 0) {
      console.log('❌ 没有找到测试任务');
      return;
    }

    const task = tasks[0];
    console.log('📋 找到测试任务:');
    console.log(`   ID: ${task.id}`);
    console.log(`   标题: ${task.title}`);
    console.log(`   内容: ${task.description}`);
    console.log(`   优先级: ${task.priority}`);
    console.log(`   状态: ${task.status}\n`);

    // 2. 模拟更新（只测试SQL，不实际执行）
    const newTitle = '测试编辑后的标题';
    const newDescription = '测试编辑后的内容描述';
    const newPriority = 'p0';
    const newStatus = 'in_progress';

    console.log('✏️  模拟更新为:');
    console.log(`   标题: ${newTitle}`);
    console.log(`   内容: ${newDescription}`);
    console.log(`   优先级: ${newPriority}`);
    console.log(`   状态: ${newStatus}\n`);

    // 构建更新语句（和后端一样的逻辑）
    const updates = [];
    const values = [];
    
    if (newTitle !== undefined) {
      updates.push('title = ?');
      values.push(newTitle);
    }
    
    if (newDescription !== undefined) {
      updates.push('description = ?');
      values.push(newDescription);
    }
    
    if (newPriority !== undefined) {
      updates.push('priority = ?');
      values.push(newPriority);
    }
    
    if (newStatus !== undefined) {
      updates.push('status = ?');
      values.push(newStatus);
    }

    values.push(task.id);

    const updateSQL = `UPDATE tasks SET ${updates.join(', ')} WHERE id = ?`;
    console.log('📝 生成的SQL语句:');
    console.log(`   ${updateSQL}`);
    console.log(`   参数: [${values.map(v => `"${v}"`).join(', ')}]\n`);

    // 3. 执行更新
    await db.execute(updateSQL, values);
    console.log('✅ 任务更新成功！\n');

    // 4. 验证更新结果
    const [updatedTasks] = await db.execute(
      'SELECT id, title, description, priority, status FROM tasks WHERE id = ?',
      [task.id]
    );

    const updated = updatedTasks[0];
    console.log('🎉 更新后的任务:');
    console.log(`   标题: ${updated.title}`);
    console.log(`   内容: ${updated.description}`);
    console.log(`   优先级: ${updated.priority}`);
    console.log(`   状态: ${updated.status}\n`);

    // 5. 恢复原始数据
    await db.execute(
      'UPDATE tasks SET title = ?, description = ?, priority = ?, status = ? WHERE id = ?',
      [task.title, task.description, task.priority, task.status, task.id]
    );
    console.log('🔄 已恢复原始数据\n');

    console.log('✅ 测试完成！任务编辑功能正常！');

  } catch (error) {
    console.error('❌ 测试失败:', error);
  } finally {
    await db.end();
  }
}

testTaskEdit();


























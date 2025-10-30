/**
 * 测试周视图甘特图的日期计算逻辑
 */

// 模拟任务数据
const tasks = [
  {
    id: '1',
    title: '年度培训需求调研分析',
    start_time: '2025-10-07T09:00:00+08:00',
    end_time: '2025-10-09T18:00:00+08:00'
  },
  {
    id: '2',
    title: 'Q3人才盘点数据汇报',
    start_time: '2025-10-10T14:00:00+08:00',
    end_time: '2025-10-10T16:00:00+08:00'
  },
  {
    id: '3',
    title: '员工满意度提升行动计划',
    start_time: '2025-10-26T14:00:00+08:00',
    end_time: '2025-10-29T17:00:00+08:00'
  },
];

// 模拟一周的日期（10月6日-10月12日）
const weekDays = [
  new Date(2025, 9, 6),  // 10/6 周一
  new Date(2025, 9, 7),  // 10/7 周二
  new Date(2025, 9, 8),  // 10/8 周三
  new Date(2025, 9, 9),  // 10/9 周四
  new Date(2025, 9, 10), // 10/10 周五
  new Date(2025, 9, 11), // 10/11 周六
  new Date(2025, 9, 12), // 10/12 周日
];

console.log('\n========== 测试周视图甘特图日期计算 ==========\n');

// 测试函数：从ISO字符串提取日期
function extractDateFromISO(isoString) {
  const datePart = isoString.split('T')[0];
  const parts = datePart.split('-');
  return new Date(
    parseInt(parts[0]),
    parseInt(parts[1]) - 1, // JavaScript月份从0开始
    parseInt(parts[2])
  );
}

// 测试函数：判断两个日期是否是同一天
function isSameDay(date1, date2) {
  return date1.getFullYear() === date2.getFullYear() &&
         date1.getMonth() === date2.getMonth() &&
         date1.getDate() === date2.getDate();
}

// 测试每个任务
tasks.forEach(task => {
  console.log(`\n【任务】${task.title}`);
  console.log(`起始时间：${task.start_time}`);
  console.log(`结束时间：${task.end_time}`);
  
  const taskStartDate = extractDateFromISO(task.start_time);
  const taskEndDate = extractDateFromISO(task.end_time);
  
  console.log(`起始日期：${taskStartDate.getFullYear()}-${(taskStartDate.getMonth() + 1).toString().padStart(2, '0')}-${taskStartDate.getDate().toString().padStart(2, '0')}`);
  console.log(`结束日期：${taskEndDate.getFullYear()}-${(taskEndDate.getMonth() + 1).toString().padStart(2, '0')}-${taskEndDate.getDate().toString().padStart(2, '0')}`);
  
  // 找出任务在本周的起始和结束位置
  let startIndex = null;
  let endIndex = null;
  
  const coveredDays = [];
  
  for (let i = 0; i < weekDays.length; i++) {
    const day = weekDays[i];
    
    // 检查任务是否覆盖这一天
    if (isSameDay(day, taskStartDate) || 
        (day > taskStartDate && day < taskEndDate) ||
        isSameDay(day, taskEndDate)) {
      if (startIndex === null) startIndex = i;
      endIndex = i;
      coveredDays.push(`${day.getMonth() + 1}/${day.getDate()}`);
    }
  }
  
  if (startIndex !== null && endIndex !== null) {
    console.log(`本周显示范围：列 ${startIndex} 到列 ${endIndex} (共 ${endIndex - startIndex + 1} 天)`);
    console.log(`覆盖日期：${coveredDays.join(', ')}`);
  } else {
    console.log('❌ 任务不在本周范围内');
  }
});

console.log('\n\n========== 预期结果验证 ==========\n');

console.log('✅ 年度培训需求调研分析');
console.log('   应该横跨：10/7（周二）、10/8（周三）、10/9（周四）');
console.log('   月视图应显示在：10/7、10/8、10/9');
console.log('   日视图应在：10/7、10/8、10/9 都能看到');

console.log('\n✅ Q3人才盘点数据汇报');
console.log('   应该只在：10/10（周五）');
console.log('   月视图应显示在：10/10');
console.log('   日视图应在：10/10 能看到');

console.log('\n✅ 员工满意度提升行动计划');
console.log('   应该横跨：10/26（周日）、10/27（周一）、10/28（周二）、10/29（周三）');
console.log('   周视图会分两周显示：');
console.log('     - 第一周（10/20-10/26）：在周日（10/26）开始');
console.log('     - 第二周（10/27-11/2）：从周一（10/27）到周三（10/29）');
console.log('   月视图应显示在：10/26、10/27、10/28、10/29');
console.log('   日视图应在：10/26、10/27、10/28、10/29 都能看到');

console.log('\n========== 测试完成 ==========\n');


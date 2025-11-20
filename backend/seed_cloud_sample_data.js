const mysql = require('mysql2/promise');
const { randomUUID } = require('crypto');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

const dbConfig = {
  host: process.env.DB_HOST || 'rm-2ze22f1xm8vvw4m44to.mysql.rds.aliyuncs.com',
  user: process.env.DB_USER || 'pdl',
  password: process.env.DB_PASSWORD || 'Pdl123456',
  database: process.env.DB_NAME || 'enterprise_management',
  port: Number(process.env.DB_PORT || 3306),
  charset: 'utf8mb4',
  multipleStatements: true
};

const targetUsernames = [
  'admin',
  'founder1',
  'founder2',
  'hr_head',
  'finance_head',
  'marketing_head',
  'hr_team1',
  'finance_team1',
  'marketing_team1',
  'hr_emp1',
  'finance_emp1',
  'marketing_emp1'
];

const colorPalette = ['#5E35B1', '#00838F', '#EF6C00', '#3949AB', '#00897B', '#C62828', '#9C27B0'];

const taskTemplatesByRole = {
  admin: [
    {
      title: '系统巡检与权限核对',
      date: '2025-10-10',
      startHour: 9,
      durationHours: 2,
      priority: 'p1',
      status: 'completed',
      progress: 100,
      description: '完成季度系统巡检与权限清理，整理风控报告。'
    },
    {
      title: '跨部门流程协调会',
      date: '2025-11-05',
      startHour: 14,
      durationHours: 2,
      priority: 'p1',
      status: 'in_progress',
      progress: 60,
      description: '主持跨部门流程协同会议，梳理审批链路。'
    },
    {
      title: '信息安全整改计划跟进',
      date: '2025-11-22',
      startHour: 10,
      durationHours: 2,
      priority: 'p0',
      status: 'pending',
      progress: 0,
      description: '推进信息安全整改计划，与技术部确认上线节奏。'
    }
  ],
  founder: [
    {
      title: '季度战略复盘会',
      date: '2025-10-15',
      startHour: 10,
      durationHours: 3,
      priority: 'p0',
      status: 'completed',
      progress: 100,
      description: '回顾 Q3 战略执行情况，形成 Q4 重点方向。'
    },
    {
      title: '核心团队对齐会',
      date: '2025-11-12',
      startHour: 15,
      durationHours: 2,
      priority: 'p1',
      status: 'in_progress',
      progress: 40,
      description: '与核心团队对齐预算与业务目标，确定 KPI 调整。'
    },
    {
      title: '投资人季度汇报',
      date: '2025-11-24',
      startHour: 9,
      durationHours: 3,
      priority: 'p0',
      status: 'pending',
      progress: 0,
      description: '准备投资人会议材料，更新增长与盈利预测。'
    }
  ],
  department_head: [
    {
      title: '部门 OKR 复盘',
      date: '2025-10-08',
      startHour: 9,
      durationHours: 2,
      priority: 'p1',
      status: 'completed',
      progress: 100,
      description: '完成部门 Q3 OKR 复盘，沉淀问题项。'
    },
    {
      title: '预算线沟通与定调',
      date: '2025-11-09',
      startHour: 11,
      durationHours: 2,
      priority: 'p1',
      status: 'in_progress',
      progress: 55,
      description: '与财务确认 2026 预算线，评估用工结构。'
    },
    {
      title: 'Q4 项目风险排查',
      date: '2025-11-23',
      startHour: 13,
      durationHours: 2,
      priority: 'p0',
      status: 'pending',
      progress: 0,
      description: '排查本季度关键项目风险，输出跟进清单。'
    }
  ],
  team_leader: [
    {
      title: '小组周例会',
      date: '2025-10-11',
      startHour: 10,
      durationHours: 1.5,
      priority: 'p2',
      status: 'completed',
      progress: 100,
      description: '召开周例会，跟踪执行问题与数据。'
    },
    {
      title: '专项事项推进',
      date: '2025-10-27',
      startHour: 14,
      durationHours: 2,
      priority: 'p1',
      status: 'in_progress',
      progress: 50,
      description: '推进专项事项，与跨部门同事确认依赖。'
    },
    {
      title: '月中复盘与计划',
      date: '2025-11-15',
      startHour: 9,
      durationHours: 2,
      priority: 'p1',
      status: 'in_progress',
      progress: 20,
      description: '月中点复盘排期，更新优先级。'
    },
    {
      title: '项目验收准备',
      date: '2025-11-25',
      startHour: 15,
      durationHours: 2,
      priority: 'p0',
      status: 'pending',
      progress: 0,
      description: '准备项目验收材料，确认交付指标。'
    }
  ],
  employee: [
    {
      title: '周度数据整理',
      date: '2025-10-09',
      startHour: 9,
      durationHours: 2,
      priority: 'p2',
      status: 'completed',
      progress: 100,
      description: '整理周度数据，提交团队看板。'
    },
    {
      title: '专项材料准备',
      date: '2025-10-21',
      startHour: 13,
      durationHours: 2,
      priority: 'p2',
      status: 'in_progress',
      progress: 35,
      description: '为专项项目准备支持材料。'
    },
    {
      title: '例行沟通记录',
      date: '2025-11-06',
      startHour: 11,
      durationHours: 1.5,
      priority: 'p2',
      status: 'in_progress',
      progress: 40,
      description: '跟业务侧对齐需求，整理沟通记录。'
    },
    {
      title: '阶段成果汇报',
      date: '2025-11-18',
      startHour: 16,
      durationHours: 1.5,
      priority: 'p1',
      status: 'pending',
      progress: 0,
      description: '准备阶段成果 PPT，确认数据准确性。'
    }
  ]
};

const logTemplatesByRole = {
  admin: [
    { title: '后台巡检及工单追踪', date: '2025-10-07', content: '排查后台指标波动情况，并更新工单状态。' },
    { title: '审批链路优化复盘', date: '2025-10-28', content: '梳理审批链路优化建议并形成 SOP。' },
    { title: '会议纪要整理', date: '2025-11-10', content: '整理管理层会议纪要并同步各部门。' },
    { title: '风控例会记录', date: '2025-11-18', content: '记录风控例会关键动作与后续跟进。' }
  ],
  founder: [
    { title: '业务盘点与策略思考', date: '2025-10-05', content: '盘点业务增长指标，思考策略调整。' },
    { title: '区域市场调研日记', date: '2025-10-22', content: '拜访重点客户，确认区域策略。' },
    { title: '组织文化访谈记录', date: '2025-11-08', content: '与多位同事访谈，收集文化建设反馈。' },
    { title: '预算审阅心得', date: '2025-11-17', content: '审阅预算版本，并提出优化方向。' }
  ],
  department_head: [
    { title: '季度人才评审总结', date: '2025-10-06', content: '完成季度人才评审并输出重点名单。' },
    { title: '流程自动化推进日记', date: '2025-10-24', content: '推进流程自动化项目，记录阻塞点。' },
    { title: '业务侧沟通纪要', date: '2025-11-04', content: '与业务负责人对齐 OKR，更新诉求。' },
    { title: '培训项目反思', date: '2025-11-16', content: '总结培训活动反馈，优化后续计划。' }
  ],
  team_leader: [
    { title: '周会输出与反馈', date: '2025-10-09', content: '整理周会关键结论，跟进责任事项。' },
    { title: '专项复盘记录', date: '2025-10-26', content: '复盘专项任务执行情况，标记风险。' },
    { title: '一对一访谈记录', date: '2025-11-03', content: '完成小组成员一对一，梳理诉求。' },
    { title: '排期调整说明', date: '2025-11-14', content: '根据资源变动更新排期，写明原因。' }
  ],
  employee: [
    { title: '需求确认笔记', date: '2025-10-08', content: '整理需求确认要点并同步至文档。' },
    { title: '数据清洗日志', date: '2025-10-20', content: '描述数据清洗过程与遇到的问题。' },
    { title: '跨组协作纪要', date: '2025-11-02', content: '跨组沟通协作事项并记录结论。' },
    { title: '阶段自我复盘', date: '2025-11-15', content: '记录阶段成果和下一步计划。' }
  ]
};

function formatDate(date) {
  const pad = (n) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

function buildDate(dateStr, hour = 10, durationHours = 2) {
  const start = new Date(`${dateStr}T${String(hour).padStart(2, '0')}:00:00+08:00`);
  const end = new Date(start.getTime() + durationHours * 60 * 60 * 1000);
  return { start, end };
}

async function seedData() {
  const connection = await mysql.createConnection(dbConfig);
  try {
    const placeholders = targetUsernames.map(() => '?').join(',');
    const [users] = await connection.execute(
      `SELECT u.id, u.username, u.name, u.role, u.department_id, d.name AS department_name
       FROM users u
       LEFT JOIN departments d ON u.department_id = d.id
       WHERE u.username IN (${placeholders})
       ORDER BY FIELD(u.username, ${placeholders})`,
      [...targetUsernames, ...targetUsernames]
    );

    if (users.length === 0) {
      console.log('未找到指定测试账户，无法导入示例数据。');
      return;
    }

    const userIds = users.map((u) => u.id);
    if (userIds.length > 0) {
      const idPlaceholders = userIds.map(() => '?').join(',');
      await connection.execute(
        `DELETE FROM tasks WHERE assignee_id IN (${idPlaceholders}) AND title LIKE '【示例%'`,
        userIds
      );
      await connection.execute(
        `DELETE FROM personal_logs WHERE user_id IN (${idPlaceholders}) AND title LIKE '【示例%'`,
        userIds
      );
    }

    let taskInserted = 0;
    let logInserted = 0;

    for (const [index, user] of users.entries()) {
      const roleKey =
        user.role === 'founder'
          ? 'founder'
          : user.role === 'department_head'
          ? 'department_head'
          : user.role === 'team_leader'
          ? 'team_leader'
          : user.role === 'admin'
          ? 'admin'
          : 'employee';

      const color = colorPalette[index % colorPalette.length];
      const taskTemplates = taskTemplatesByRole[roleKey] || taskTemplatesByRole.employee;
      const logTemplates = logTemplatesByRole[roleKey] || logTemplatesByRole.employee;

      for (const spec of taskTemplates) {
        const [existing] = await connection.execute(
          'SELECT id FROM tasks WHERE assignee_id = ? AND title = ? LIMIT 1',
          [user.id, spec.title]
        );
        if (existing.length > 0) continue;

        const { start, end } = buildDate(spec.date, spec.startHour, spec.durationHours);
        const deadline = new Date(end.getTime() + 60 * 60 * 1000);

        await connection.execute(
          `INSERT INTO tasks (
            id, title, description, assignee_id, assignee_name, department_id,
            priority, status, progress_percentage, start_time, end_time, deadline,
            color, is_all_day, created_by, attachments
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            randomUUID(),
            spec.title,
            `${spec.description}（责任人：${user.name}）`,
            user.id,
            user.name,
            user.department_id,
            spec.priority,
            spec.status,
            spec.progress,
            formatDate(start),
            formatDate(end),
            formatDate(deadline),
            color,
            false,
            user.id,
            JSON.stringify([])
          ]
        );
        taskInserted += 1;
      }

      for (const spec of logTemplates) {
        const [existingLog] = await connection.execute(
          'SELECT id FROM personal_logs WHERE user_id = ? AND title = ? LIMIT 1',
          [user.id, spec.title]
        );
        if (existingLog.length > 0) continue;

        const logDate = new Date(`${spec.date}T17:30:00+08:00`);
        await connection.execute(
          `INSERT INTO personal_logs (
            id, user_id, title, content, category, quadrant,
            created_at, log_date, keywords, images, location_name,
            location_latitude, location_longitude
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            randomUUID(),
            user.id,
            spec.title,
            `${spec.content}（记录人：${user.name}）`,
            '工作记录',
            'important_not_urgent',
            formatDate(logDate),
            spec.date,
            '复盘,记录,计划',
            JSON.stringify([]),
            null,
            null,
            null
          ]
        );
        logInserted += 1;
      }
    }

    console.log(`任务新增: ${taskInserted} 条`);
    console.log(`日志新增: ${logInserted} 条`);
  } catch (error) {
    console.error('初始化数据失败:', error);
    process.exitCode = 1;
  } finally {
    await connection.end();
  }
}

seedData();



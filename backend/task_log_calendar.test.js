const request = require('supertest');
const mysql = require('mysql2/promise');
const { app, initDatabase } = require('./server_enterprise');

// 1. 告诉 Jest 劫持 'mysql2/promise' 模块
// *修正点*: 实际代码使用 createPool，不是 createConnection
jest.mock('mysql2/promise', () => ({
  createPool: jest.fn(),
}));

// 2. 准备一个全局的 mock 数据库连接池对象
const mockDb = {
  execute: jest.fn(),
  query: jest.fn(),
  end: jest.fn(),
  getConnection: jest.fn(), // 连接池需要 getConnection 方法
};

describe('API (任务、日志、日历模块)', () => {

  let token; // 用于存储登录后的 token (employee)
  let managerToken; // 用于存储有权限用户的 token (manager)
  
  // 模拟的用户
  const mockUser = {
    id: 'employee-001',
    username: 'hr_emp1',
    password: 'hremp123', // 数据库明文密码
    role: 'employee',
    department_id: 'dept-001'
  };

  const mockManager = {
    id: 'manager-001',
    username: 'hr_manager',
    password: 'hrmgr123',
    role: 'team_leader', // 有权限创建任务
    department_id: 'dept-001'
  };

  beforeAll(async () => {
    // 3. 设置 createPool 返回我们的 mockDb (连接池)
    // *修正点*: 实际代码使用 mysql.createPool()
    mysql.createPool.mockReturnValue(mockDb);

    // 4. 模拟数据库初始化（创建表等）
    mockDb.query.mockResolvedValue();
    mockDb.execute.mockResolvedValue();

    // 5. 模拟登录获取 Token (employee)
    mockDb.execute.mockResolvedValueOnce([ [mockUser] ]); // 模拟 SELECT user
    mockDb.execute.mockResolvedValueOnce(); // 模拟 UPDATE last_login_at

    const res = await request(app)
      .post('/api/auth/login')
      .send({ username: mockUser.username, password: mockUser.password });
    
    token = res.body.token; // 保存 token 供后续测试使用

    // 6. 模拟登录获取 Manager Token (用于创建任务等需要权限的操作)
    mockDb.execute.mockResolvedValueOnce([ [mockManager] ]); // 模拟 SELECT user
    mockDb.execute.mockResolvedValueOnce(); // 模拟 UPDATE last_login_at

    const managerRes = await request(app)
      .post('/api/auth/login')
      .send({ username: mockManager.username, password: mockManager.password });
    
    managerToken = managerRes.body.token; // 保存 manager token
  });

  // 每次测试前清除模拟次数记录
  beforeEach(() => {
    mockDb.execute.mockClear();
    mockDb.query.mockClear();
    mockDb.getConnection.mockClear(); // 清除 getConnection 的调用记录
  });

  // --- 任务模块测试 ---
  describe('GET /api/tasks', () => {
    it('应该返回该员工的任务列表', async () => {
      // 1. 准备 mock 数据
      const mockTasks = [
        { id: 'task-001', title: '完成Q4季度报告', assignee_id: 'employee-001' },
      ];
      
      // 2. 模拟 db.execute 返回任务数据
      mockDb.execute.mockResolvedValueOnce([ mockTasks ]);

      // 3. 发起请求 (携带 token)
      const response = await request(app)
        .get('/api/tasks')
        .set('Authorization', `Bearer ${token}`);

      // 4. 验证
      expect(response.statusCode).toBe(200);
      expect(response.body.length).toBe(1);
      expect(response.body[0].title).toBe('完成Q4季度报告');
      // 验证 SQL 查询是否正确（确保是查 employee-001 的）
      expect(mockDb.execute.mock.calls[0][0]).toContain('AND t.assignee_id = ?');
      expect(mockDb.execute.mock.calls[0][1]).toContain('employee-001');
    });

    it('没有 token 应返回 401', async () => {
      const response = await request(app).get('/api/tasks');
      expect(response.statusCode).toBe(401);
    });
  });

  // --- 创建任务模块测试 ---
  describe('POST /api/tasks', () => {
    it('应该成功创建任务 (manager)', async () => {
      // 1. 模拟查询被分配人信息 (server_enterprise.js L1531-1534)
      const mockAssignee = {
        name: '陈人事专员',
        department_id: 'dept-001'
      };
      // *修正点*: 实际代码查询 name 和 department_id
      mockDb.execute.mockResolvedValueOnce([ [mockAssignee] ]); // SELECT name, department_id FROM users

      // 2. 模拟 INSERT 任务
      mockDb.execute.mockResolvedValueOnce(); // INSERT INTO tasks

      // 3. 模拟创建通知
      mockDb.execute.mockResolvedValueOnce(); // INSERT INTO task_notifications

      // 4. 发起请求
      const response = await request(app)
        .post('/api/tasks')
        .set('Authorization', `Bearer ${managerToken}`) // 使用 manager token
        .send({
          title: '新任务',
          description: '任务描述',
          assignee_id: 'employee-001',
          department_id: 'dept-001', // 需要这个字段
          priority: 'p1',
          deadline: '2025-12-31T23:59:59Z',
          start_time: '2025-12-01T09:00:00Z',
          end_time: '2025-12-01T18:00:00Z',
          is_all_day: false
        });

      // 5. 验证
      expect(response.statusCode).toBe(201);
      expect(response.body.message).toBe('任务创建成功');
      
      // 6. 验证数据库调用
      expect(mockDb.execute).toHaveBeenCalledTimes(3);
      expect(mockDb.execute.mock.calls[0][0]).toContain('SELECT name, department_id FROM users WHERE id = ?');
      expect(mockDb.execute.mock.calls[1][0]).toContain('INSERT INTO tasks');
      expect(mockDb.execute.mock.calls[2][0]).toContain('INSERT INTO task_notifications');
    });

    it('员工无权创建任务应返回 403', async () => {
      const response = await request(app)
        .post('/api/tasks')
        .set('Authorization', `Bearer ${token}`) // 使用 employee token
        .send({
          title: '新任务',
          assignee_id: 'employee-001'
        });

      expect(response.statusCode).toBe(403);
      expect(response.body.error).toBe('员工无权创建任务');
      // 验证数据库未被调用
      expect(mockDb.execute).toHaveBeenCalledTimes(0);
    });
    
    it('缺少必填字段应返回 400', async () => {
      // *修正点*: server_enterprise.js L1517-1522 有参数验证，缺少 title 或 assignee_id 会返回 400
      const response = await request(app)
        .post('/api/tasks')
        .set('Authorization', `Bearer ${managerToken}`)
        .send({
          description: '任务描述',
          assignee_id: 'employee-001'
          // 缺少 title
        });

      expect(response.statusCode).toBe(400);
      expect(response.body.error).toBe('任务名称不能为空');
    });
  });

  // --- 更新任务状态模块测试 ---
  describe('PUT /api/tasks/:id/status', () => {
    it('应该成功更新任务状态（被分配人）', async () => {
      const taskId = 'task-001';
      const mockTask = {
        id: taskId,
        assignee_id: mockUser.id, // 当前登录用户(employee)是被分配人
        created_by: mockManager.id,
        parent_task_id: null
      };

      // 1. 模拟 SELECT 任务 (server_enterprise.js L1608)
      // *修正点*: 实际代码会查询创建者信息用于权限检查
      mockDb.execute.mockResolvedValueOnce([ [mockTask] ]);

      // 2. 模拟 SELECT 创建者信息 (server_enterprise.js L1620-1623)
      const mockCreator = {
        id: mockManager.id,
        role: 'team_leader',
        department_id: 'dept-001'
      };
      mockDb.execute.mockResolvedValueOnce([ [mockCreator] ]);

      // 3. 模拟 UPDATE 任务状态
      mockDb.execute.mockResolvedValueOnce(); // UPDATE tasks

      // 4. 发起请求
      const response = await request(app)
        .put(`/api/tasks/${taskId}/status`)
        .set('Authorization', `Bearer ${token}`) // 使用 employee token
        .send({
          status: 'in_progress',
          progress_percentage: 50
        });

      // 5. 验证
      expect(response.statusCode).toBe(200);
      expect(response.body.message).toBe('任务状态更新成功');

      // 6. 验证数据库调用
      expect(mockDb.execute).toHaveBeenCalledTimes(3);
      expect(mockDb.execute.mock.calls[0][0]).toContain('SELECT * FROM tasks WHERE id = ?');
      expect(mockDb.execute.mock.calls[1][0]).toContain('SELECT id, role, department_id FROM users WHERE id = ?');
      expect(mockDb.execute.mock.calls[2][0]).toContain('UPDATE tasks SET');
      expect(mockDb.execute.mock.calls[2][1][0]).toBe('in_progress'); // status
    });

    it('无权更新此任务应返回 403', async () => {
      const taskId = 'task-002';
      const mockTask = {
        id: taskId,
        assignee_id: 'employee-999', // 不是当前用户
        created_by: 'other-manager-001',
      };

      // 1. 模拟 SELECT 任务
      mockDb.execute.mockResolvedValueOnce([ [mockTask] ]);

      // 2. 模拟 SELECT 创建者信息
      const mockCreator = {
        id: 'other-manager-001',
        role: 'admin', // 创建者是 admin，当前用户是 employee，无权更新
        department_id: 'dept-999' // 不同部门
      };
      mockDb.execute.mockResolvedValueOnce([ [mockCreator] ]);

      // 3. 发起请求 (使用 managerToken，但 manager 不是被分配人且不符合其他权限条件)
      const response = await request(app)
        .put(`/api/tasks/${taskId}/status`)
        .set('Authorization', `Bearer ${managerToken}`) // 使用 manager token
        .send({ status: 'in_progress' });

      // 4. 验证
      expect(response.statusCode).toBe(403);
      // *修正点*: 匹配 server_enterprise.js L1650 的错误消息
      expect(response.body.error).toBe('无权更新此任务进度');
      expect(mockDb.execute).toHaveBeenCalledTimes(2); // SELECT 任务 + SELECT 创建者
    });

    it('任务不存在应返回 404', async () => {
      // 模拟 SELECT 任务返回空结果
      mockDb.execute.mockResolvedValueOnce([ [] ]);

      const response = await request(app)
        .put('/api/tasks/non-existent-task/status')
        .set('Authorization', `Bearer ${token}`)
        .send({
          status: 'in_progress'
        });

      expect(response.statusCode).toBe(404);
      expect(response.body.error).toBe('任务不存在');
    });
  });

  // --- 删除任务模块测试 ---
  describe('DELETE /api/tasks/:id', () => {
    it('应该成功删除任务（创建者）', async () => {
      const taskId = 'task-004';
      const mockTask = {
        id: taskId,
        assignee_id: 'employee-999',
        created_by: mockManager.id, // 当前用户(manager)是创建者
      };

      // 1. 模拟 SELECT 任务 (server_enterprise.js L1886)
      mockDb.execute.mockResolvedValueOnce([ [mockTask] ]);
      // 2. 模拟 UPDATE 子任务（将子任务的parent_task_id设置为NULL）
      mockDb.execute.mockResolvedValueOnce(); // UPDATE tasks SET parent_task_id = NULL
      // 3. 模拟 DELETE 任务通知
      mockDb.execute.mockResolvedValueOnce(); // DELETE FROM task_notifications
      // 4. 模拟 DELETE 任务 (server_enterprise.js L2012)
      mockDb.execute.mockResolvedValueOnce(); // DELETE FROM tasks

      // 5. 发起请求
      const response = await request(app)
        .delete(`/api/tasks/${taskId}`)
        .set('Authorization', `Bearer ${managerToken}`); // 使用 manager token

      // 6. 验证
      expect(response.statusCode).toBe(200);
      expect(response.body.message).toBe('任务删除成功');
      expect(mockDb.execute).toHaveBeenCalledTimes(4);
      expect(mockDb.execute.mock.calls[3][0]).toContain('DELETE FROM tasks');
    });

    it('无权删除此任务应返回 403 (非创建者)', async () => {
      const taskId = 'task-005';
      const mockTask = {
        id: taskId,
        assignee_id: mockUser.id, // 当前用户是被分配人
        created_by: mockManager.id, // 但不是创建者
      };

      // 1. 模拟 SELECT 任务
      mockDb.execute.mockResolvedValueOnce([ [mockTask] ]);

      // 2. 发起请求
      const response = await request(app)
        .delete(`/api/tasks/${taskId}`)
        .set('Authorization', `Bearer ${token}`); // 使用 employee token

      // 3. 验证
      expect(response.statusCode).toBe(403);
      // *修正点*: 匹配 server_enterprise.js L1982 的错误消息
      expect(response.body.error).toBe('无权删除此任务，只能删除自己创建的任务、分配给自己的任务，或分配给下属的任务');
      expect(mockDb.execute).toHaveBeenCalledTimes(1); // 只有 SELECT
    });

    it('任务不存在应返回 404', async () => {
      // 模拟 SELECT 任务返回空结果
      mockDb.execute.mockResolvedValueOnce([ [] ]);

      const response = await request(app)
        .delete('/api/tasks/non-existent-task')
        .set('Authorization', `Bearer ${token}`);

      expect(response.statusCode).toBe(404);
      expect(response.body.error).toBe('任务不存在');
    });
  });

  // --- 日历视图测试 ---
  describe('GET /api/calendar/month-view', () => {
    it('应该返回该员工的月视图数据', async () => {
      const mockTasks = [ { id: 'task-001', title: '月视图任务' } ];
      const mockLogs = [ { id: 'log-001', title: '月视图日志' } ];
      
      // 1. 模拟任务查询
      mockDb.execute.mockResolvedValueOnce([ mockTasks ]);
      // 2. 模拟日志查询
      mockDb.execute.mockResolvedValueOnce([ mockLogs ]);

      const response = await request(app)
        .get('/api/calendar/month-view?year=2025&month=10')
        .set('Authorization', `Bearer ${token}`);

      expect(response.statusCode).toBe(200);
      expect(response.body.summary.totalTasks).toBe(1);
      expect(response.body.summary.totalLogs).toBe(1);
    });

    it('不带 year 参数应返回 400', async () => {
      const response = await request(app)
        .get('/api/calendar/month-view?month=10')
        .set('Authorization', `Bearer ${token}`);

      expect(response.statusCode).toBe(400);
      expect(response.body.error).toBe('请提供年份(year)和月份(month)参数');
    });

    it('不带 month 参数应返回 400', async () => {
      const response = await request(app)
        .get('/api/calendar/month-view?year=2025')
        .set('Authorization', `Bearer ${token}`);

      expect(response.statusCode).toBe(400);
      expect(response.body.error).toBe('请提供年份(year)和月份(month)参数');
    });

    it('不带任何参数应返回 400', async () => {
      const response = await request(app)
        .get('/api/calendar/month-view')
        .set('Authorization', `Bearer ${token}`);

      expect(response.statusCode).toBe(400);
      expect(response.body.error).toBe('请提供年份(year)和月份(month)参数');
    });
  });

  // --- 日详情视图测试 ---
  describe('GET /api/calendar/day-detail', () => {
    it('应该返回该员工的日详情数据', async () => {
      const mockTasks = [
        {
          id: 'task-001',
          title: '日视图任务',
          description: '任务描述',
          status: 'pending',
          priority: 'p1',
          color: '#FF0000',
          start_time: '2025-10-15 09:00:00',
          end_time: '2025-10-15 17:00:00',
          deadline: null,
          is_all_day: false,
          assignee_name: '员工A',
          department_name: '技术部',
          creator_name: '经理B'
        }
      ];
      const mockLogs = [
        {
          id: 'log-001',
          title: '日视图日志',
          content: '日志内容',
          category: '工作',
          quadrant: '重要紧急',
          is_completed: 0,
          created_at: '2025-10-15 10:00:00'
        }
      ];

      // 1. 模拟任务查询
      mockDb.execute.mockResolvedValueOnce([ mockTasks ]);

      // 2. 模拟日志查询
      mockDb.execute.mockResolvedValueOnce([ mockLogs ]);

      // 3. 发起请求
      const response = await request(app)
        .get('/api/calendar/day-detail?date=2025-10-15')
        .set('Authorization', `Bearer ${token}`);

      // 4. 验证
      expect(response.statusCode).toBe(200);
      expect(response.body.date).toBe('2025-10-15');
      expect(response.body.tasks).toBeDefined();
      expect(response.body.tasks.length).toBe(1);
      expect(response.body.tasks[0].title).toBe('日视图任务');
      expect(response.body.logs).toBeDefined();
      expect(response.body.logs.length).toBe(1);
      expect(response.body.logs[0].title).toBe('日视图日志');

      // 5. 验证数据库调用
      expect(mockDb.execute.mock.calls[0][0]).toContain('SELECT');
      expect(mockDb.execute.mock.calls[0][0]).toContain('FROM tasks');
      expect(mockDb.execute.mock.calls[0][1]).toContain('employee-001'); // assignee_id
      expect(mockDb.execute.mock.calls[0][1]).toContain('2025-10-15'); // date

      expect(mockDb.execute.mock.calls[1][0]).toContain('SELECT');
      expect(mockDb.execute.mock.calls[1][0]).toContain('FROM personal_logs');
      expect(mockDb.execute.mock.calls[1][1]).toContain('employee-001'); // user_id
      expect(mockDb.execute.mock.calls[1][1]).toContain('2025-10-15'); // date
    });

    it('不带 date 参数应返回 400', async () => {
      const response = await request(app)
        .get('/api/calendar/day-detail')
        .set('Authorization', `Bearer ${token}`);

      expect(response.statusCode).toBe(400);
      expect(response.body.error).toBe('请提供日期(date)参数，格式: YYYY-MM-DD');
    });

    it('应该正确处理空数据', async () => {
      // 1. 模拟任务查询返回空数组
      mockDb.execute.mockResolvedValueOnce([ [] ]);

      // 2. 模拟日志查询返回空数组
      mockDb.execute.mockResolvedValueOnce([ [] ]);

      // 3. 发起请求
      const response = await request(app)
        .get('/api/calendar/day-detail?date=2025-10-15')
        .set('Authorization', `Bearer ${token}`);

      // 4. 验证
      expect(response.statusCode).toBe(200);
      expect(response.body.date).toBe('2025-10-15');
      expect(response.body.tasks).toEqual([]);
      expect(response.body.logs).toEqual([]);
    });
  });

  // --- 个人日志模块测试 ---
  describe('GET /api/personal-logs', () => {
    it('应该返回该员工的个人日志列表（含 taskUpdates）', async () => {
      const mockLogs = [
        {
          id: 'log-001',
          user_id: mockUser.id,
          title: '工作日志1',
          content: '日志内容1',
          category: '工作',
          is_completed: 0,
          created_at: '2025-10-15T10:00:00.000Z'
        },
        {
          id: 'log-002',
          user_id: mockUser.id,
          title: '工作日志2',
          content: '日志内容2',
          category: '学习',
          is_completed: 1,
          created_at: '2025-10-16T10:00:00.000Z'
        }
      ];

      // 1. 模拟查询 personal_logs (server_enterprise.js L2598-2601)
      mockDb.execute.mockResolvedValueOnce([ mockLogs ]);

      // 2. 模拟查询 log_task_linkage (server_enterprise.js L2605-2611)
      // *修正点*: SQL 查询包含 t.title as task_name，所以返回数据包含 task_name
      // 对每个日志都会查询一次关联任务（使用 Promise.all 并行查询）
      const mockLinkages1 = [
        {
          task_id: 'task-001',
          task_name: '任务1', // SQL 查询包含 t.title as task_name
          progress_percentage: 50,
          task_status: 'in_progress'
        }
      ];
      const mockLinkages2 = []; // 第二个日志没有关联任务

      mockDb.execute.mockResolvedValueOnce([ mockLinkages1 ]); // log-001 的关联
      mockDb.execute.mockResolvedValueOnce([ mockLinkages2 ]); // log-002 的关联

      // 3. 发起请求
      const response = await request(app)
        .get('/api/personal-logs')
        .set('Authorization', `Bearer ${token}`);

      // 4. 验证
      expect(response.statusCode).toBe(200);
      expect(response.body).toBeInstanceOf(Array);
      expect(response.body.length).toBe(2);
      expect(response.body[0].title).toBe('工作日志1');
      // *修正点*: 后端返回的字段名是 taskUpdates (server_enterprise.js L2616)，不是 linkages
      expect(response.body[0].taskUpdates).toBeDefined();
      expect(response.body[0].taskUpdates.length).toBe(1);
      expect(response.body[0].taskUpdates[0].taskId).toBe('task-001');
      expect(response.body[0].taskUpdates[0].taskName).toBe('任务1');
      expect(response.body[1].taskUpdates).toBeDefined();
      expect(response.body[1].taskUpdates.length).toBe(0);

      // 5. 验证数据库调用
      expect(mockDb.execute).toHaveBeenCalledTimes(3);
      expect(mockDb.execute.mock.calls[0][0]).toContain('SELECT * FROM personal_logs WHERE user_id = ?');
      expect(mockDb.execute.mock.calls[0][1][0]).toBe(mockUser.id);
      // 验证关联任务查询包含 task_name
      expect(mockDb.execute.mock.calls[1][0]).toContain('SELECT l.task_id, t.title as task_name');
      expect(mockDb.execute.mock.calls[1][0]).toContain('FROM log_task_linkage');
    });
  });

  describe('POST /api/personal-logs', () => {
    it('应该成功创建个人日志（不含 linkages）', async () => {
      // 模拟事务相关方法
      const mockConnection = {
        execute: jest.fn(),
        beginTransaction: jest.fn(),
        commit: jest.fn(),
        release: jest.fn(),
      };
      
      // 模拟 db.getConnection (server_enterprise.js L2527)
      // *修正点*: mockDb 是连接池，需要 getConnection 方法
      mockDb.getConnection.mockResolvedValueOnce(mockConnection);
      
      // 1. 模拟 INSERT personal_logs (server_enterprise.js L2537-2540)
      mockConnection.execute.mockResolvedValueOnce();
      
      // 2. 模拟查询创建的日志 (server_enterprise.js L2570)
      const mockCreatedLog = {
        id: 'log-new-001',
        user_id: mockUser.id,
        title: '新日志',
        content: '日志内容',
        category: '工作',
        is_completed: 0,
        created_at: '2025-10-15T10:00:00.000Z'
      };
      mockConnection.execute.mockResolvedValueOnce([ [mockCreatedLog] ]);
      
      // 3. 模拟查询关联任务（空数组）(server_enterprise.js L2571-2576)
      mockConnection.execute.mockResolvedValueOnce([ [] ]);

      // 4. 发起请求
      const response = await request(app)
        .post('/api/personal-logs')
        .set('Authorization', `Bearer ${token}`)
        .send({
          log: {
            title: '新日志',
            content: '日志内容',
            category: '工作',
            is_completed: false,
            log_date: '2025-10-15'
          },
          linkages: []
        });

      // 5. 验证
      expect(response.statusCode).toBe(201);
      // *修正点*: 实际返回创建的日志对象，包含 taskUpdates 字段
      expect(response.body.title).toBe('新日志');
      expect(response.body.taskUpdates).toBeDefined();
      expect(response.body.taskUpdates).toEqual([]);
      
      // 6. 验证事务调用
      expect(mockDb.getConnection).toHaveBeenCalledTimes(1);
      expect(mockConnection.beginTransaction).toHaveBeenCalledTimes(1);
      expect(mockConnection.commit).toHaveBeenCalledTimes(1);
      expect(mockConnection.release).toHaveBeenCalledTimes(1);
    });

    it('应该成功创建个人日志（含 linkages）', async () => {
      const mockConnection = {
        execute: jest.fn(),
        beginTransaction: jest.fn(),
        commit: jest.fn(),
        release: jest.fn(),
      };
      
      // *修正点*: 使用 mockResolvedValueOnce 而不是直接赋值
      mockDb.getConnection.mockResolvedValueOnce(mockConnection);
      
      // 1. 模拟 INSERT personal_logs (server_enterprise.js L2537-2540)
      mockConnection.execute.mockResolvedValueOnce();
      
      // 2. 模拟 INSERT log_task_linkage (server_enterprise.js L2555-2561)
      mockConnection.execute.mockResolvedValueOnce(); // INSERT log_task_linkage
      
      // 3. 模拟 syncTaskStatusFromLog 中的 SELECT 任务 (server_enterprise.js L666)
      const mockTask = {
        progress_percentage: 30,
        status: 'pending'
      };
      mockConnection.execute.mockResolvedValueOnce([ [mockTask] ]); // SELECT tasks FOR UPDATE
      
      // 4. 模拟 syncTaskStatusFromLog 中的 UPDATE 任务（如果需要更新）
      mockConnection.execute.mockResolvedValueOnce(); // UPDATE tasks (如果需要)
      
      // 5. 模拟查询创建的日志 (server_enterprise.js L2570)
      const mockCreatedLog = {
        id: 'log-new-002',
        user_id: mockUser.id,
        title: '带关联任务的日志',
        category: '工作',
        is_completed: 0
      };
      mockConnection.execute.mockResolvedValueOnce([ [mockCreatedLog] ]);
      
      // 6. 模拟查询关联任务 (server_enterprise.js L2571-2576)
      const mockLinkages = [
        {
          task_id: 'task-001',
          task_name: '任务1',
          progress_percentage: 50,
          task_status: 'in_progress'
        }
      ];
      mockConnection.execute.mockResolvedValueOnce([ mockLinkages ]);

      // 7. 发起请求
      const response = await request(app)
        .post('/api/personal-logs')
        .set('Authorization', `Bearer ${token}`)
        .send({
          log: {
            title: '带关联任务的日志',
            category: '工作',
            is_completed: false,
            log_date: '2025-10-15'
          },
          linkages: [
            {
              task_id: 'task-001',
              progress_percentage: 50,
              task_status: 'in_progress'
            }
          ]
        });

      // 8. 验证
      expect(response.statusCode).toBe(201);
      // *修正点*: 实际返回创建的日志对象，包含 taskUpdates 字段
      expect(response.body.title).toBe('带关联任务的日志');
      expect(response.body.taskUpdates).toBeDefined();
      expect(response.body.taskUpdates.length).toBe(1);
      expect(response.body.taskUpdates[0].taskId).toBe('task-001');
      expect(response.body.taskUpdates[0].taskName).toBe('任务1');
    });

    it('缺少必填字段应返回 400', async () => {
      const response = await request(app)
        .post('/api/personal-logs')
        .set('Authorization', `Bearer ${token}`)
        .send({
          log: {
            content: '日志内容'
            // 缺少 title 和 category
          }
        });

      expect(response.statusCode).toBe(400);
      expect(response.body.error).toBe('缺少必填字段 (title, category)');
    });
  });

  describe('DELETE /api/personal-logs/:id', () => {
    it('应该成功删除个人日志', async () => {
      const logId = 'log-001';

      // 1. 模拟验证权限 (server_enterprise.js L2771)
      // SELECT id FROM personal_logs WHERE id = ? AND user_id = ?
      mockDb.execute.mockResolvedValueOnce([ [{ id: logId }] ]);

      // 2. 模拟 DELETE (server_enterprise.js L2777)
      mockDb.execute.mockResolvedValueOnce(); // DELETE FROM personal_logs

      // 3. 发起请求
      const response = await request(app)
        .delete(`/api/personal-logs/${logId}`)
        .set('Authorization', `Bearer ${token}`);

      // 4. 验证
      expect(response.statusCode).toBe(204); // *修正点*: 实际返回 204，不是 200
      // 204 状态码通常没有响应体

      // 5. 验证数据库调用
      expect(mockDb.execute).toHaveBeenCalledTimes(2);
      expect(mockDb.execute.mock.calls[0][0]).toContain('SELECT id FROM personal_logs WHERE id = ? AND user_id = ?');
      expect(mockDb.execute.mock.calls[1][0]).toContain('DELETE FROM personal_logs');
    });

    it('无权删除此日志应返回 404', async () => {
      const logId = 'log-002';

      // 1. 模拟验证权限返回空结果（日志不存在或不属于当前用户）
      mockDb.execute.mockResolvedValueOnce([ [] ]);

      // 2. 发起请求
      const response = await request(app)
        .delete(`/api/personal-logs/${logId}`)
        .set('Authorization', `Bearer ${token}`);

      // 3. 验证
      expect(response.statusCode).toBe(404);
      // *修正点*: 匹配 server_enterprise.js L2773 的错误消息
      expect(response.body.error).toBe('Log not found or access denied.');
      expect(mockDb.execute).toHaveBeenCalledTimes(1); // 只有 SELECT
    });
  });
});
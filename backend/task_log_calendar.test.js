// backend/task_log_calendar.test.js

// ==========================================
// 1. 环境配置 (必须在所有 require 之前)
// ==========================================
process.env.JWT_SECRET = 'test_fixed_secret_key_123456'; // 固定密钥，防止 403
process.env.PORT = '3002'; // 防止端口冲突

// ==========================================
// 2. 定义全局 Mock 对象 (关键步骤)
// ==========================================
const mockFunctions = {
  execute: jest.fn(),
  query: jest.fn(),
  end: jest.fn(),
  getConnection: jest.fn(),
};

// 模拟的连接对象 (用于事务 beginTransaction 等)
const mockConnectionObj = {
  execute: jest.fn(),
  query: jest.fn(),
  beginTransaction: jest.fn(),
  commit: jest.fn(),
  release: jest.fn(),
  rollback: jest.fn()
};

// ==========================================
// 3. Jest Mock 注入
// ==========================================
jest.mock('mysql2/promise', () => {
  return {
    createPool: jest.fn(() => ({
      execute: mockFunctions.execute,
      query: mockFunctions.query,
      end: mockFunctions.end,
      getConnection: mockFunctions.getConnection,
    })),
  };
});

// ==========================================
// 4. 引入依赖 (必须在 mock 之后)
// ==========================================
const request = require('supertest');
const jwt = require('jsonwebtoken');
const { app, initDatabase } = require('./server_enterprise'); // 你的服务器入口

// 为了兼容你原本的测试写法，我们把全局 mock 函数包装进 mockDb
const mockDb = {
  execute: mockFunctions.execute,
  query: mockFunctions.query,
  getConnection: mockFunctions.getConnection,
  end: mockFunctions.end
};

describe('API (任务、日志、日历模块)', () => {
  let token;        // 普通员工 Token
  let managerToken; // 经理 Token

  const mockUser = {
    id: 'employee-001',
    username: 'hr_emp1',
    role: 'employee',
    department_id: 'dept-001'
  };

  const mockManager = {
    id: 'manager-001',
    username: 'hr_manager',
    role: 'team_leader',
    department_id: 'dept-001'
  };

  // ==========================================
  // 5. 初始化 Token
  // ==========================================
  beforeAll(async () => {
    mockFunctions.getConnection.mockResolvedValue(mockConnectionObj);
    mockConnectionObj.query.mockResolvedValue([]);

    mockFunctions.execute.mockResolvedValue([ [{ count: 0 }], [] ]);
    if (initDatabase) {
      await initDatabase();
    } else {
      console.warn("警告: 未在 server_enterprise.js 中找到 initDatabase 导出，数据库可能未初始化！");
    }
    // 直接生成 Token，跳过登录接口测试（登录接口由于涉及数据库 UPDATE，很难在 BeforeAll 里完美模拟）
    // 只要密钥和 server 一致，Token 就是有效的
    token = jwt.sign(
      mockUser,
      process.env.JWT_SECRET,
      { expiresIn: '1h' }
    );

    managerToken = jwt.sign(
      mockManager,
      process.env.JWT_SECRET,
      { expiresIn: '1h' }
    );
  });

  // ==========================================
  // 6. 每个测试前的重置 (关键)
  // ==========================================
  beforeEach(() => {
    // 1. 清除调用记录
    jest.resetAllMocks();

    // 2. 【非常重要】设置鉴权中间件的默认通过行为
    // 这里的逻辑是：当鉴权中间件查数据库 "SELECT * FROM users WHERE id = ?" 时
    // 我们默认让它返回一个存在的用户，这样就不会报 403 了。
    // mockFunctions.execute 默认行为：第一次调用返回用户，后续调用返回空数组(或其他测试指定的值)
    mockFunctions.getConnection.mockResolvedValue(mockConnectionObj);

    mockConnectionObj.query.mockResolvedValue([]);
    mockFunctions.execute.mockResolvedValue([ [mockUser], [] ]);
  });

  // --- 任务模块测试 ---
  describe('GET /api/tasks', () => {
    it('应该返回该员工的任务列表', async () => {
      const mockTasks = [
        { id: 'task-001', title: '完成Q4季度报告', assignee_id: 'employee-001' },
      ];

      // 第一次调用是鉴权(已在beforeEach处理)，我们需要覆盖掉，或者追加返回值
      // 为了稳妥，我们直接用 mockResolvedValue 覆盖整个队列
      mockFunctions.execute
        .mockResolvedValueOnce([ mockTasks, [] ]);

      const response = await request(app)
        .get('/api/tasks')
        .set('Authorization', `Bearer ${token}`);

      expect(response.statusCode).toBe(200);
      expect(response.body.length).toBe(1);
      expect(response.body[0].title).toBe('完成Q4季度报告');
    });

    it('没有 token 应返回 401', async () => {
      const response = await request(app).get('/api/tasks');
      expect(response.statusCode).toBe(401);
    });
  });

  // --- 创建任务模块测试 ---
  describe('POST /api/tasks', () => {
    it('应该成功创建任务 (manager)', async () => {
      mockFunctions.execute
        .mockResolvedValueOnce([ [mockManager] ]) // 1. 鉴权查询
        .mockResolvedValueOnce([ [{ name: '陈人事', department_id: 'dept-001' }] ]) // 2. 查询被分配人
        .mockResolvedValueOnce([ { insertId: 1 } ]) // 3. INSERT tasks
        .mockResolvedValueOnce([ { insertId: 1 } ]); // 4. INSERT notifications

      const response = await request(app)
        .post('/api/tasks')
        .set('Authorization', `Bearer ${managerToken}`)
        .send({
          title: '新任务',
          description: '任务描述',
          assignee_id: 'employee-001',
          department_id: 'dept-001',
          priority: 'p1',
          deadline: '2025-12-31',
          start_time: '2025-12-01',
          end_time: '2025-12-01',
          is_all_day: false
        });

      expect(response.statusCode).toBe(201);
      expect(response.body.message).toBe('任务创建成功');
    });

    it('员工无权创建任务应返回 403', async () => {
      // 员工 Token 进行操作
      mockFunctions.execute.mockResolvedValueOnce([ [mockUser] ]); // 1. 鉴权查询

      const response = await request(app)
        .post('/api/tasks')
        .set('Authorization', `Bearer ${token}`)
        .send({
          title: '新任务',
          assignee_id: 'employee-001'
        });

      expect(response.statusCode).toBe(403);
      // 确保不是 "无效的访问令牌"，而是 "权限不足"
      // 注意：这里根据你的业务逻辑，可能是 '员工无权创建任务' 或 'Forbidden'
      expect(response.body.error).toMatch(/无权|forbidden|denied/i);
    });

    it('缺少必填字段应返回 400', async () => {
      mockFunctions.execute.mockResolvedValueOnce([ [mockManager] ]); // 1. 鉴权查询

      const response = await request(app)
        .post('/api/tasks')
        .set('Authorization', `Bearer ${managerToken}`)
        .send({
          description: '没有标题'
          // 缺少 title
        });

      expect(response.statusCode).toBe(400);
    });
  });

  // --- 更新任务状态模块测试 ---
  describe('PUT /api/tasks/:id/status', () => {
    it('应该成功更新任务状态', async () => {
      const taskId = 'task-001';
      const mockTask = { id: taskId, assignee_id: mockUser.id, created_by: 'mgr-01' };
      const mockCreator = { id: 'mgr-01', role: 'manager' };

      mockFunctions.execute
        .mockResolvedValueOnce([ [mockTask], [] ])    // 2. SELECT task
        .mockResolvedValueOnce([ [mockCreator], [] ]) // 3. SELECT creator
        .mockResolvedValueOnce([ { affectedRows: 1 }, [] ]); // 4. UPDATE

      const response = await request(app)
        .put(`/api/tasks/${taskId}/status`)
        .set('Authorization', `Bearer ${token}`)
        .send({ status: 'in_progress', progress_percentage: 50 });

      expect(response.statusCode).toBe(200);
    });
  });

  // --- 日历视图测试 ---
  describe('GET /api/calendar/month-view', () => {
    it('应该返回该员工的月视图数据', async () => {
      mockFunctions.execute
        .mockResolvedValueOnce([ [{ id: 1 }], [] ]) // 2. 查询任务
        .mockResolvedValueOnce([ [{ id: 1 }], [] ]); // 3. 查询日志

      const response = await request(app)
        .get('/api/calendar/month-view?year=2025&month=10')
        .set('Authorization', `Bearer ${token}`);

      expect(response.statusCode).toBe(200);
      expect(response.body.summary).toBeDefined();
    });
  });

  // --- 个人日志模块测试 (包含事务 Mock) ---
  describe('POST /api/personal-logs', () => {
    it('应该成功创建个人日志（不含 linkages）', async () => {


      // 准备: 事务内的执行结果
      mockConnectionObj.execute
        .mockResolvedValueOnce([ { insertId: 100 }, [] ]) // INSERT log
        .mockResolvedValueOnce([ [{ id: 100, title: '新日志' }], [] ]) // SELECT created log
        .mockResolvedValueOnce([ [], [] ]); // SELECT linkages

      const response = await request(app)
        .post('/api/personal-logs')
        .set('Authorization', `Bearer ${token}`)
        .send({
          title: '新日志',
          content: '日志内容',
          log_date: '2025-11-13',
          category: 'work'
        });

      expect(response.statusCode).toBe(201);
      expect(response.body.id).toBe(100);
      expect(response.body.title).toBe('新日志');

    });
  });
  });
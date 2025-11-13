module.exports = {
  testEnvironment: 'node',
  clearMocks: true,
  // 覆盖率报告将包含 lcov (用于 CI) 和 html (用于本地查看)
  coverageReporters: ['lcov', 'text', 'html'],
  // 明确告诉 Jest 只统计核心业务文件的覆盖率
  collectCoverageFrom: [
    'server_enterprise.js',
  ],
  // 详细显示测试报告
  verbose: true,
};
class Config {
  static const String baseUrl = 'http://localhost:8080/api';
  
  // API端点配置
  static const String loginEndpoint = '/auth/login';
  static const String logsEndpoint = '/logs';
  static const String personalLogsEndpoint = '/personal-logs';
  static const String tasksEndpoint = '/tasks';
  static const String usersEndpoint = '/users';
  
  // 应用配置
  static const String appName = '企业管理系统';
  static const String appVersion = '1.0.0';
  
  // 超时配置
  static const int requestTimeout = 30000; // 30秒
  
  // 分页配置
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
}

const http = require('http');

// 测试服务器是否可达
const req = http.get('http://localhost:3000/', (res) => {
  console.log(`服务器状态: ${res.statusCode}`);
  console.log('✓ 服务器正在运行');
});

req.on('error', (error) => {
  console.error('✗ 服务器连接失败:', error.message);
  console.error('请确保后端服务器正在运行 (node server_enterprise.js)');
});

req.end();



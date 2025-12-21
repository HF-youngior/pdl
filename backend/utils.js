// 简单的工具函数用于测试
function validateEmail(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

function validatePassword(password) {
  if (password === null || password === undefined) {
    throw new Error('Password cannot be null or undefined');
  }
  if (typeof password !== 'string') {
    return false;
  }
  return password.length >= 6;
}

function generateTaskId() {
  return 'task_' + Math.random().toString(36).substr(2, 9);
}

function formatDate(date) {
  return new Date(date).toISOString().split('T')[0];
}

module.exports = {
  validateEmail,
  validatePassword,
  generateTaskId,
  formatDate
};
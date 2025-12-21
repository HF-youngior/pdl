// 数据处理函数
function processTaskData(tasks) {
  return tasks.map(task => ({
    ...task,
    status: task.status || 'pending',
    priority: task.priority || 'medium',
    createdAt: task.createdAt || new Date().toISOString()
  }));
}

function filterTasksByStatus(tasks, status) {
  return tasks.filter(task => task.status === status);
}

function sortTasksByDate(tasks, order = 'desc') {
  return tasks.sort((a, b) => {
    const dateA = new Date(a.createdAt);
    const dateB = new Date(b.createdAt);
    return order === 'desc' ? dateB - dateA : dateA - dateB;
  });
}

function calculateTaskStats(tasks) {
  const total = tasks.length;
  const completed = tasks.filter(task => task.status === 'completed').length;
  const pending = tasks.filter(task => task.status === 'pending').length;
  const inProgress = tasks.filter(task => task.status === 'in-progress').length;
  
  return {
    total,
    completed,
    pending,
    inProgress,
    completionRate: total > 0 ? Math.round((completed / total) * 100) : 0
  };
}

module.exports = {
  processTaskData,
  filterTasksByStatus,
  sortTasksByDate,
  calculateTaskStats
};
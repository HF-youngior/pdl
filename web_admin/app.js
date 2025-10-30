// API基础URL
const API_BASE_URL = 'http://localhost:8080/api';

// 当前用户信息
let currentUser = null;
let currentTask = null;
let users = [];
let authToken = null;

// 页面加载完成后初始化
document.addEventListener('DOMContentLoaded', function() {
    // 检查是否已登录
    checkAuthStatus();
    
    // 添加责任人选择事件监听器
    document.addEventListener('change', function(e) {
        if (e.target.id === 'taskAssignee') {
            const selectedUser = users.find(user => user.id === e.target.value);
            if (selectedUser) {
                document.getElementById('taskDepartment').value = selectedUser.department;
            }
        }
    });
});

// 检查认证状态
function checkAuthStatus() {
    authToken = localStorage.getItem('authToken');
    if (authToken) {
        // 验证token是否有效
        validateToken();
    } else {
        // 显示登录模态框
        showLoginModal();
    }
}

// 显示登录模态框
function showLoginModal() {
    const loginModal = new bootstrap.Modal(document.getElementById('loginModal'));
    loginModal.show();
}

// 执行登录
async function performLogin() {
    const username = document.getElementById('loginUsername').value;
    const password = document.getElementById('loginPassword').value;
    const rememberMe = document.getElementById('rememberMe').checked;
    
    if (!username || !password) {
        showLoginError('请输入用户名和密码');
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE_URL}/auth/login`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ username, password })
        });
        
        const data = await response.json();
        
        if (response.ok) {
            // 登录成功
            authToken = data.token;
            currentUser = data.user;
            
            // 保存token
            if (rememberMe) {
                localStorage.setItem('authToken', authToken);
            } else {
                sessionStorage.setItem('authToken', authToken);
            }
            
            // 显示用户信息
            updateUserInfo();
            
            // 隐藏登录模态框
            const loginModal = bootstrap.Modal.getInstance(document.getElementById('loginModal'));
            loginModal.hide();
            
            // 加载数据
            loadDashboardData();
            loadUsers();
            
            showAlert('登录成功！', 'success');
        } else {
            showLoginError(data.error || '登录失败');
        }
    } catch (error) {
        console.error('登录错误:', error);
        showLoginError('网络错误，请检查服务器连接');
    }
}

// 显示登录错误
function showLoginError(message) {
    const errorDiv = document.getElementById('loginError');
    errorDiv.textContent = message;
    errorDiv.style.display = 'block';
}

// 验证token
async function validateToken() {
    try {
        const response = await fetch(`${API_BASE_URL}/user/profile`, {
            headers: {
                'Authorization': `Bearer ${authToken}`
            }
        });
        
        if (response.ok) {
            currentUser = await response.json();
            updateUserInfo();
            loadDashboardData();
            loadUsers();
        } else {
            // token无效，清除并显示登录
            localStorage.removeItem('authToken');
            sessionStorage.removeItem('authToken');
            authToken = null;
            showLoginModal();
        }
    } catch (error) {
        console.error('Token验证失败:', error);
        showLoginModal();
    }
}

// 登出
function logout() {
    localStorage.removeItem('authToken');
    sessionStorage.removeItem('authToken');
    authToken = null;
    currentUser = null;
    showLoginModal();
}

// 获取认证头
function getAuthHeaders() {
    return {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${authToken}`
    };
}

// 更新用户信息显示
function updateUserInfo() {
    if (currentUser) {
        document.getElementById('currentUserName').textContent = currentUser.name || currentUser.username;
        document.getElementById('currentUserRole').textContent = currentUser.role || '未知角色';
        document.getElementById('userInfo').style.display = 'block';
    } else {
        document.getElementById('userInfo').style.display = 'none';
    }
}

// 显示指定部分
function showSection(sectionName) {
    // 隐藏所有部分
    const sections = document.querySelectorAll('.content-section');
    sections.forEach(section => {
        section.style.display = 'none';
    });

    // 显示指定部分
    const targetSection = document.getElementById(sectionName + '-section');
    if (targetSection) {
        targetSection.style.display = 'block';
    }

    // 更新导航状态
    const navLinks = document.querySelectorAll('.nav-link');
    navLinks.forEach(link => {
        link.classList.remove('active');
    });
    event.target.classList.add('active');

    // 根据部分加载相应数据
    switch(sectionName) {
        case 'dashboard':
            loadDashboardData();
            break;
        case 'users':
            loadUsers();
            break;
        case 'important-items':
            loadImportantItems();
            break;
        case 'tasks':
            loadTasks();
            break;
        case 'logs':
            loadLogs();
            break;
    }
}

// 加载仪表板数据
async function loadDashboardData() {
    try {
        // 这里应该调用API获取统计数据
        // 由于示例数据，我们使用模拟数据
        document.getElementById('totalUsers').textContent = '12';
        document.getElementById('totalImportantItems').textContent = '8';
        document.getElementById('pendingTasks').textContent = '15';
        document.getElementById('todayLogs').textContent = '23';
    } catch (error) {
        console.error('加载仪表板数据失败:', error);
    }
}

// 加载用户列表
async function loadUsers() {
    const tbody = document.getElementById('usersTableBody');
    
    try {
        // 显示加载状态
        tbody.innerHTML = '<tr><td colspan="7" class="text-center"><i class="bi bi-hourglass-split"></i> 加载中...</td></tr>';
        
        const response = await fetch(`${API_BASE_URL}/users`, {
            headers: getAuthHeaders()
        });
        
        if (!response.ok) {
            if (response.status === 401) {
                showLoginModal();
                return;
            }
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        users = await response.json(); // 保存到全局变量
        
        tbody.innerHTML = '';
        
        if (users.length === 0) {
            tbody.innerHTML = '<tr><td colspan="7" class="text-center text-muted">暂无用户数据</td></tr>';
            return;
        }
        
        users.forEach(user => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>${user.username}</td>
                <td>${user.name}</td>
                <td>${user.position}</td>
                <td>${user.department_name || user.department || '-'}</td>
                <td><span class="badge bg-${getRoleBadgeColor(user.role)}">${user.role}</span></td>
                <td>${user.last_login_at ? new Date(user.last_login_at).toLocaleString() : '从未登录'}</td>
                <td>
                    <button class="btn btn-sm btn-outline-primary" onclick="editUser('${user.id}')">
                        <i class="bi bi-pencil"></i>
                    </button>
                    <button class="btn btn-sm btn-outline-danger" onclick="deleteUser('${user.id}')">
                        <i class="bi bi-trash"></i>
                    </button>
                </td>
            `;
            tbody.appendChild(row);
        });
    } catch (error) {
        console.error('加载用户列表失败:', error);
        tbody.innerHTML = '<tr><td colspan="7" class="text-center text-danger">加载失败: ' + error.message + '</td></tr>';
        showAlert('加载用户列表失败: ' + error.message, 'danger');
    }
}

// 加载重要事项列表
async function loadImportantItems() {
    try {
        const response = await fetch(`${API_BASE_URL}/important-items`, {
            headers: getAuthHeaders()
        });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const items = await response.json();
        
        const tbody = document.getElementById('importantItemsTableBody');
        tbody.innerHTML = '';
        
        items.forEach(item => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>${item.title}</td>
                <td>${item.description || '-'}</td>
                <td><span class="badge bg-${getPriorityBadgeColor(item.priority)}">${item.priority}</span></td>
                <td><span class="badge bg-${getStatusBadgeColor(item.status)}">${item.status}</span></td>
                <td>${item.department}</td>
                <td>${item.deadline ? new Date(item.deadline).toLocaleDateString() : '-'}</td>
                <td>
                    <button class="btn btn-sm btn-outline-primary" onclick="editImportantItem('${item.id}')">
                        <i class="bi bi-pencil"></i>
                    </button>
                    <button class="btn btn-sm btn-outline-danger" onclick="deleteImportantItem('${item.id}')">
                        <i class="bi bi-trash"></i>
                    </button>
                </td>
            `;
            tbody.appendChild(row);
        });
    } catch (error) {
        console.error('加载重要事项列表失败:', error);
        showAlert('加载重要事项列表失败', 'danger');
    }
}

// 加载任务列表
async function loadTasks() {
    try {
        const response = await fetch(`${API_BASE_URL}/tasks`, {
            headers: getAuthHeaders()
        });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        const tasks = await response.json();
        
        const tbody = document.getElementById('tasksTableBody');
        tbody.innerHTML = '';
        
        // 统计任务数量
        let totalTasks = tasks.length;
        let inProgressTasks = tasks.filter(task => task.status === 'in_progress' || task.status === 'pending').length;
        let completedTasks = tasks.filter(task => task.status === 'completed').length;
        let overdueTasks = tasks.filter(task => {
            if (!task.deadline) return false;
            return new Date(task.deadline) < new Date() && task.status !== 'completed';
        }).length;
        
        // 更新统计卡片
        document.getElementById('totalTasksCount').textContent = totalTasks;
        document.getElementById('inProgressTasksCount').textContent = inProgressTasks;
        document.getElementById('completedTasksCount').textContent = completedTasks;
        document.getElementById('overdueTasksCount').textContent = overdueTasks;
        
        tasks.forEach(task => {
            const row = document.createElement('tr');
            const progress = calculateTaskProgress(task);
            const isOverdue = task.deadline && new Date(task.deadline) < new Date() && task.status !== 'completed';
            
            row.innerHTML = `
                <td>
                    <div class="d-flex align-items-center">
                        <div class="me-2" style="width: 12px; height: 12px; background-color: ${task.color || '#4CAF50'}; border-radius: 50%;"></div>
                        <span class="${isOverdue ? 'text-danger fw-bold' : ''}">${task.title}</span>
                    </div>
                </td>
                <td>${task.description ? (task.description.length > 50 ? task.description.substring(0, 50) + '...' : task.description) : '-'}</td>
                <td>${task.assignee_name}</td>
                <td>${task.department}</td>
                <td><span class="badge bg-${getPriorityBadgeColor(task.priority)}">${getPriorityText(task.priority)}</span></td>
                <td><span class="badge bg-${getStatusBadgeColor(task.status)}">${getStatusText(task.status)}</span></td>
                <td>
                    <div class="progress" style="height: 20px;">
                        <div class="progress-bar ${getProgressBarColor(progress)}" role="progressbar" style="width: ${progress}%">
                            ${progress}%
                        </div>
                    </div>
                </td>
                <td class="${isOverdue ? 'text-danger fw-bold' : ''}">${task.deadline ? new Date(task.deadline).toLocaleDateString() : '-'}</td>
                <td>
                    <button class="btn btn-sm btn-outline-info" onclick="viewTaskDetail('${task.id}')" title="查看详情">
                        <i class="bi bi-eye"></i>
                    </button>
                    <button class="btn btn-sm btn-outline-primary" onclick="editTask('${task.id}')" title="编辑">
                        <i class="bi bi-pencil"></i>
                    </button>
                    <button class="btn btn-sm btn-outline-danger" onclick="deleteTask('${task.id}')" title="删除">
                        <i class="bi bi-trash"></i>
                    </button>
                </td>
            `;
            tbody.appendChild(row);
        });
    } catch (error) {
        console.error('加载任务列表失败:', error);
        showAlert('加载任务列表失败', 'danger');
    }
}

// 加载日志列表
async function loadLogs() {
    try {
        const response = await fetch(`${API_BASE_URL}/logs`);
        const logs = await response.json();
        
        const tbody = document.getElementById('logsTableBody');
        tbody.innerHTML = '';
        
        logs.forEach(log => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>${new Date(log.created_at).toLocaleString()}</td>
                <td>${log.user_name}</td>
                <td>${log.action}</td>
                <td>${log.description || '-'}</td>
                <td><span class="badge bg-${getCategoryBadgeColor(log.category)}">${log.category}</span></td>
            `;
            tbody.appendChild(row);
        });
    } catch (error) {
        console.error('加载日志列表失败:', error);
        showAlert('加载日志列表失败', 'danger');
    }
}

// 显示添加用户模态框
function showAddUserModal() {
    const modal = new bootstrap.Modal(document.getElementById('addUserModal'));
    modal.show();
}

// 添加用户
async function addUser() {
    const form = document.getElementById('addUserForm');
    const formData = new FormData(form);
    
    const userData = {
        username: document.getElementById('username').value,
        password: document.getElementById('password').value,
        name: document.getElementById('name').value,
        position: document.getElementById('position').value,
        department: document.getElementById('department').value,
        role: document.getElementById('role').value
    };

    try {
        const response = await fetch(`${API_BASE_URL}/users`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(userData)
        });

        if (response.ok) {
            showAlert('用户添加成功', 'success');
            bootstrap.Modal.getInstance(document.getElementById('addUserModal')).hide();
            form.reset();
            loadUsers();
        } else {
            const error = await response.json();
            showAlert(error.message || '添加用户失败', 'danger');
        }
    } catch (error) {
        console.error('添加用户失败:', error);
        showAlert('添加用户失败', 'danger');
    }
}

// 显示添加重要事项模态框
function showAddImportantItemModal() {
    // 清空表单
    document.getElementById('importantItemTitle').value = '';
    document.getElementById('importantItemDescription').value = '';
    document.getElementById('importantItemPriority').value = 'p1';
    document.getElementById('importantItemDeadline').value = '';
    
    const modal = new bootstrap.Modal(document.getElementById('addImportantItemModal'));
    modal.show();
}

// 添加重要事项
async function addImportantItem() {
    const title = document.getElementById('importantItemTitle').value;
    const description = document.getElementById('importantItemDescription').value;
    const priority = document.getElementById('importantItemPriority').value;
    const deadline = document.getElementById('importantItemDeadline').value;
    
    if (!title.trim()) {
        showAlert('请输入事项标题', 'warning');
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE_URL}/company-important-items`, {
            method: 'POST',
            headers: getAuthHeaders(),
            body: JSON.stringify({
                title: title.trim(),
                description: description.trim(),
                priority: priority,
                deadline: deadline || null
            })
        });
        
        if (response.ok) {
            showAlert('重要事项添加成功', 'success');
            bootstrap.Modal.getInstance(document.getElementById('addImportantItemModal')).hide();
            loadImportantItems();
        } else {
            const error = await response.json();
            showAlert(error.message || '添加重要事项失败', 'danger');
        }
    } catch (error) {
        console.error('添加重要事项失败:', error);
        showAlert('添加重要事项失败', 'danger');
    }
}

// 编辑重要事项
async function editImportantItem(itemId) {
    try {
        // 获取事项详情
        const response = await fetch(`${API_BASE_URL}/company-important-items/all`, {
            headers: getAuthHeaders()
        });
        
        if (!response.ok) {
            throw new Error('获取事项详情失败');
        }
        
        const items = await response.json();
        const item = items.find(i => i.id === itemId);
        
        if (!item) {
            showAlert('未找到该事项', 'warning');
            return;
        }
        
        // 填充编辑表单
        document.getElementById('editImportantItemId').value = item.id;
        document.getElementById('editImportantItemTitle').value = item.title;
        document.getElementById('editImportantItemDescription').value = item.description || '';
        document.getElementById('editImportantItemPriority').value = item.priority;
        document.getElementById('editImportantItemStatus').value = item.status;
        document.getElementById('editImportantItemDeadline').value = item.deadline ? new Date(item.deadline).toISOString().slice(0, 16) : '';
        
        const modal = new bootstrap.Modal(document.getElementById('editImportantItemModal'));
        modal.show();
    } catch (error) {
        console.error('获取事项详情失败:', error);
        showAlert('获取事项详情失败', 'danger');
    }
}

// 更新重要事项
async function updateImportantItem() {
    const id = document.getElementById('editImportantItemId').value;
    const title = document.getElementById('editImportantItemTitle').value;
    const description = document.getElementById('editImportantItemDescription').value;
    const priority = document.getElementById('editImportantItemPriority').value;
    const status = document.getElementById('editImportantItemStatus').value;
    const deadline = document.getElementById('editImportantItemDeadline').value;
    
    if (!title.trim()) {
        showAlert('请输入事项标题', 'warning');
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE_URL}/company-important-items/${id}`, {
            method: 'PUT',
            headers: getAuthHeaders(),
            body: JSON.stringify({
                title: title.trim(),
                description: description.trim(),
                priority: priority,
                status: status,
                deadline: deadline || null
            })
        });
        
        if (response.ok) {
            showAlert('重要事项更新成功', 'success');
            bootstrap.Modal.getInstance(document.getElementById('editImportantItemModal')).hide();
            loadImportantItems();
        } else {
            const error = await response.json();
            showAlert(error.message || '更新重要事项失败', 'danger');
        }
    } catch (error) {
        console.error('更新重要事项失败:', error);
        showAlert('更新重要事项失败', 'danger');
    }
}

// 删除重要事项
async function deleteImportantItem(itemId) {
    if (!confirm('确定要删除这个重要事项吗？此操作不可撤销！')) {
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE_URL}/company-important-items/${itemId}`, {
            method: 'DELETE',
            headers: getAuthHeaders()
        });
        
        if (response.ok) {
            showAlert('重要事项已删除', 'success');
            loadImportantItems();
        } else {
            const error = await response.json();
            showAlert(error.message || '删除重要事项失败', 'danger');
        }
    } catch (error) {
        console.error('删除重要事项失败:', error);
        showAlert('删除重要事项失败', 'danger');
    }
}

// 批量选择重要事项（十大事项编辑）
async function batchSelectImportantItems() {
    try {
        // 获取所有事项
        const response = await fetch(`${API_BASE_URL}/company-important-items/all`, {
            headers: getAuthHeaders()
        });
        
        if (!response.ok) {
            throw new Error('获取事项列表失败');
        }
        
        const items = await response.json();
        
        // 创建选择界面
        const modal = new bootstrap.Modal(document.getElementById('batchSelectModal'));
        
        // 填充选择列表
        const selectList = document.getElementById('batchSelectList');
        selectList.innerHTML = '';
        
        items.forEach(item => {
            const itemDiv = document.createElement('div');
            itemDiv.className = 'form-check';
            itemDiv.innerHTML = `
                <input class="form-check-input" type="checkbox" value="${item.id}" id="select-${item.id}" ${item.is_selected ? 'checked' : ''}>
                <label class="form-check-label" for="select-${item.id}">
                    <strong>${item.title}</strong>
                    <br><small class="text-muted">${item.description || '无描述'}</small>
                </label>
            `;
            selectList.appendChild(itemDiv);
        });
        
        modal.show();
    } catch (error) {
        console.error('获取事项列表失败:', error);
        showAlert('获取事项列表失败', 'danger');
    }
}

// 保存批量选择
async function saveBatchSelection() {
    const checkboxes = document.querySelectorAll('#batchSelectList input[type="checkbox"]:checked');
    const selectedIds = Array.from(checkboxes).map(cb => cb.value);
    
    if (selectedIds.length > 10) {
        showAlert('最多只能选择10个重要事项', 'warning');
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE_URL}/company-important-items/batch-select`, {
            method: 'PUT',
            headers: getAuthHeaders(),
            body: JSON.stringify({
                selectedIds: selectedIds
            })
        });
        
        if (response.ok) {
            showAlert(`已成功选择 ${selectedIds.length} 个重要事项`, 'success');
            bootstrap.Modal.getInstance(document.getElementById('batchSelectModal')).hide();
            loadImportantItems();
        } else {
            const error = await response.json();
            showAlert(error.message || '保存选择失败', 'danger');
        }
    } catch (error) {
        console.error('保存批量选择失败:', error);
        showAlert('保存选择失败', 'danger');
    }
}

// 显示添加任务模态框
function showAddTaskModal() {
    // 填充用户列表
    const assigneeSelect = document.getElementById('taskAssignee');
    assigneeSelect.innerHTML = '<option value="">选择责任人</option>';
    
    users.forEach(user => {
        const option = document.createElement('option');
        option.value = user.id;
        const departmentDisplay = user.department_name || user.department || '未知部门';
        option.textContent = `${user.name} (${departmentDisplay})`;
        option.dataset.department = departmentDisplay;
        assigneeSelect.appendChild(option);
    });
    
    // 设置默认时间
    const now = new Date();
    const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    document.getElementById('taskStartTime').value = now.toISOString().slice(0, 16);
    document.getElementById('taskDeadline').value = tomorrow.toISOString().slice(0, 16);
    
    const modal = new bootstrap.Modal(document.getElementById('addTaskModal'));
    modal.show();
}

// 创建任务
async function createTask() {
    const form = document.getElementById('addTaskForm');
    
    // 检查表单验证
    if (!form.checkValidity()) {
        form.reportValidity();
        return;
    }
    
    const assigneeSelect = document.getElementById('taskAssignee');
    const selectedUserId = assigneeSelect.value;
    
    if (!selectedUserId) {
        showAlert('请选择责任人', 'warning');
        return;
    }
    
    const selectedUser = users.find(user => user.id === selectedUserId);
    
    if (!selectedUser) {
        showAlert('未找到选中的用户', 'danger');
        return;
    }
    
    if (!selectedUser.department_id) {
        showAlert('用户缺少部门信息', 'danger');
        return;
    }
    
    // 处理时间字段
    const startTime = document.getElementById('taskStartTime').value;
    const deadline = document.getElementById('taskDeadline').value;
    const isAllDay = document.getElementById('taskIsAllDay').checked;
    
    // 格式化时间为后端期望的格式 (YYYY-MM-DD HH:MM:SS)
    const formatDateTime = (datetimeLocal) => {
        if (!datetimeLocal) return null;
        return datetimeLocal.replace('T', ' ') + ':00';
    };
    
    // 将前端优先级值转换为后端期望的格式
    const priorityMapping = {
        'important_urgent': 'p0',
        'important_not_urgent': 'p1',
        'not_important_urgent': 'p2',
        'not_important_not_urgent': 'p3'
    };
    
    const frontendPriority = document.getElementById('taskPriority').value;
    const backendPriority = priorityMapping[frontendPriority] || 'p1';
    
    const taskData = {
        title: document.getElementById('taskTitle').value,
        description: document.getElementById('taskDescription').value || '',
        priority: backendPriority,
        assignee_id: selectedUserId,
        department_id: selectedUser.department_id,
        start_time: startTime ? formatDateTime(startTime) : null,
        end_time: deadline ? formatDateTime(deadline) : null,
        deadline: deadline ? formatDateTime(deadline) : null,
        location: document.getElementById('taskLocation').value || null,
        is_all_day: isAllDay
    };
    
    try {
        const response = await fetch(`${API_BASE_URL}/tasks`, {
            method: 'POST',
            headers: getAuthHeaders(),
            body: JSON.stringify(taskData)
        });

        if (response.ok || response.status === 201) {
            showAlert('任务发布成功！', 'success');
            
            // 关闭模态框
            bootstrap.Modal.getInstance(document.getElementById('addTaskModal')).hide();
            
            // 重置表单
            form.reset();
            
            // 清除父任务ID（如果有）
            const parentTaskIdField = document.getElementById('parentTaskId');
            if (parentTaskIdField) {
                parentTaskIdField.remove();
            }
            
            // 恢复模态框标题
            const modalTitle = document.querySelector('#addTaskModal .modal-title');
            if (modalTitle) {
                modalTitle.textContent = '新建任务';
            }
            
            // 刷新任务列表
            loadTasks();
        } else {
            const error = await response.json();
            showAlert(error.error || error.message || '发布任务失败', 'danger');
        }
    } catch (error) {
        console.error('发布任务失败:', error);
        showAlert('发布任务失败: ' + error.message, 'danger');
    }
}

// 查看任务详情
async function viewTaskDetail(taskId) {
    try {
        const response = await fetch(`${API_BASE_URL}/tasks/${taskId}`);
        if (!response.ok) {
            throw new Error('获取任务详情失败');
        }
        
        currentTask = await response.json();
        
        // 填充任务详情
        document.getElementById('detailTaskTitle').textContent = currentTask.title;
        document.getElementById('detailTaskDescription').textContent = currentTask.description || '无';
        document.getElementById('detailTaskAssignee').textContent = currentTask.assignee_name;
        document.getElementById('detailTaskDepartment').textContent = currentTask.department;
        document.getElementById('detailTaskPriority').textContent = getPriorityText(currentTask.priority);
        document.getElementById('detailTaskStatus').textContent = getStatusText(currentTask.status);
        document.getElementById('detailTaskStartTime').textContent = currentTask.start_time ? new Date(currentTask.start_time).toLocaleString() : '未设置';
        document.getElementById('detailTaskDeadline').textContent = currentTask.deadline ? new Date(currentTask.deadline).toLocaleString() : '未设置';
        document.getElementById('detailTaskCreatedAt').textContent = currentTask.created_at ? new Date(currentTask.created_at).toLocaleString() : '未知';
        document.getElementById('detailTaskCreatedBy').textContent = currentTask.created_by || '未知';
        
        // 更新进度条
        const progress = calculateTaskProgress(currentTask);
        const progressBar = document.getElementById('taskProgressBar');
        const progressText = document.getElementById('taskProgressText');
        progressBar.style.width = `${progress}%`;
        progressBar.className = `progress-bar ${getProgressBarColor(progress)}`;
        progressText.textContent = `${progress}%`;
        
        // 加载关联日志
        await loadTaskLogs(taskId);
        
        // 显示模态框
        const modal = new bootstrap.Modal(document.getElementById('taskDetailModal'));
        modal.show();
    } catch (error) {
        console.error('获取任务详情失败:', error);
        showAlert('获取任务详情失败: ' + (error.message || ''), 'danger');
    }
}

// 加载任务关联的日志
async function loadTaskLogs(taskId) {
    try {
        const response = await fetch(`${API_BASE_URL}/logs?taskId=${taskId}`);
        const logs = await response.json();
        
        const logsList = document.getElementById('taskLogsList');
        logsList.innerHTML = '';
        
        if (logs.length === 0) {
            logsList.innerHTML = '<p class="text-muted">暂无相关日志</p>';
            return;
        }
        
        logs.forEach(log => {
            const logItem = document.createElement('div');
            logItem.className = 'border-bottom pb-3 mb-3';
            logItem.innerHTML = `
                <div class="d-flex justify-content-between align-items-start">
                    <div>
                        <h6 class="mb-1">${log.title || '工作日志'}</h6>
                        <p class="mb-2 text-muted">${log.content}</p>
                        <small class="text-muted">
                            <i class="bi bi-person"></i> ${log.user_name} 
                            <i class="bi bi-clock ms-2"></i> ${new Date(log.created_at).toLocaleString()}
                        </small>
                    </div>
                    <span class="badge bg-${getCategoryBadgeColor(log.category)}">${log.category}</span>
                </div>
            `;
            logsList.appendChild(logItem);
        });
        
        document.getElementById('detailTaskLogsCount').textContent = logs.length;
        document.getElementById('detailTaskLastActivity').textContent = logs.length > 0 ? new Date(logs[0].created_at).toLocaleString() : '无';
    } catch (error) {
        console.error('加载任务日志失败:', error);
    }
}

// 完成任务
async function completeTask() {
    if (!currentTask) return;
    
    if (confirm('确定要完成这个任务吗？')) {
        try {
            const response = await fetch(`${API_BASE_URL}/tasks/${currentTask.id}/status`, {
                method: 'PUT',
                headers: getAuthHeaders(),
                body: JSON.stringify({
                    status: 'completed',
                    progress_percentage: 100
                })
            });

            if (response.ok) {
                showAlert('任务已完成！', 'success');
                
                // 刷新任务详情
                await viewTaskDetail(currentTask.id);
                
                // 刷新任务列表
                loadTasks();
            } else {
                const error = await response.json();
                showAlert(error.error || error.message || '完成任务失败', 'danger');
            }
        } catch (error) {
            console.error('完成任务失败:', error);
            showAlert('完成任务失败: ' + error.message, 'danger');
        }
    }
}

// 更新任务进度
async function updateTaskProgress() {
    if (!currentTask) {
        showAlert('请先选择一个任务', 'warning');
        return;
    }
    
    const progressInput = prompt('请输入新的进度百分比 (0-100):', currentTask.progress_percentage || 0);
    if (progressInput === null) return; // 用户取消
    
    const progress = parseInt(progressInput);
    if (isNaN(progress) || progress < 0 || progress > 100) {
        showAlert('请输入有效的进度值 (0-100)', 'warning');
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE_URL}/tasks/${currentTask.id}/status`, {
            method: 'PUT',
            headers: getAuthHeaders(),
            body: JSON.stringify({
                progress_percentage: progress,
                status: progress === 100 ? 'completed' : (progress > 0 ? 'in_progress' : 'pending')
            })
        });
        
        if (response.ok) {
            showAlert('进度更新成功！', 'success');
            // 刷新任务详情
            await viewTaskDetail(currentTask.id);
            // 刷新任务列表
            loadTasks();
        } else {
            const error = await response.json();
            showAlert(error.error || '更新进度失败', 'danger');
        }
    } catch (error) {
        console.error('更新进度失败:', error);
        showAlert('更新进度失败: ' + error.message, 'danger');
    }
}

// 删除任务
async function deleteTask(taskId) {
    if (!taskId) taskId = currentTask?.id;
    if (!taskId) return;
    
    if (confirm('确定要删除这个任务吗？此操作不可撤销！')) {
        try {
            const response = await fetch(`${API_BASE_URL}/tasks/${taskId}`, {
                method: 'DELETE',
                headers: getAuthHeaders()
            });

            if (response.ok) {
                showAlert('任务已删除！', 'success');
                
                // 关闭详情模态框（如果有）
                const detailModalInstance = bootstrap.Modal.getInstance(document.getElementById('taskDetailModal'));
                if (detailModalInstance) {
                    detailModalInstance.hide();
                }
                
                // 清除当前任务
                currentTask = null;
                
                // 刷新任务列表
                loadTasks();
            } else {
                const error = await response.json();
                showAlert(error.error || error.message || '删除任务失败', 'danger');
            }
        } catch (error) {
            console.error('删除任务失败:', error);
            showAlert('删除任务失败: ' + error.message, 'danger');
        }
    }
}

// 刷新日志
function refreshLogs() {
    loadLogs();
}

// 工具函数
function getRoleBadgeColor(role) {
    switch(role) {
        case 'admin': return 'danger';
        case 'manager': return 'warning';
        case 'employee': return 'primary';
        default: return 'secondary';
    }
}

function getPriorityBadgeColor(priority) {
    switch(priority) {
        case 'important_urgent': return 'danger';
        case 'important_not_urgent': return 'primary';
        case 'not_important_urgent': return 'warning';
        case 'not_important_not_urgent': return 'secondary';
        case 'urgent': return 'danger';
        case 'high': return 'warning';
        case 'medium': return 'primary';
        case 'low': return 'secondary';
        default: return 'secondary';
    }
}

function getPriorityText(priority) {
    switch(priority) {
        case 'important_urgent': return '重要且紧急';
        case 'important_not_urgent': return '重要不紧急';
        case 'not_important_urgent': return '紧急不重要';
        case 'not_important_not_urgent': return '不重要不紧急';
        case 'urgent': return '紧急';
        case 'high': return '高';
        case 'medium': return '中';
        case 'low': return '低';
        default: return priority;
    }
}

function getStatusText(status) {
    switch(status) {
        case 'pending': return '待开始';
        case 'in_progress': return '进行中';
        case 'completed': return '已完成';
        case 'cancelled': return '已取消';
        default: return status;
    }
}

function getProgressBarColor(progress) {
    if (progress >= 100) return 'bg-success';
    if (progress >= 70) return 'bg-primary';
    if (progress >= 40) return 'bg-warning';
    return 'bg-danger';
}

function calculateTaskProgress(task) {
    // 根据任务状态计算进度
    switch(task.status) {
        case 'pending': return 0;
        case 'in_progress': return 50;
        case 'completed': return 100;
        case 'cancelled': return 0;
        default: return 0;
    }
}

function getStatusBadgeColor(status) {
    switch(status) {
        case 'completed': return 'success';
        case 'in_progress': return 'primary';
        case 'pending': return 'warning';
        case 'cancelled': return 'danger';
        default: return 'secondary';
    }
}

function getCategoryBadgeColor(category) {
    switch(category) {
        case 'login': return 'primary';
        case 'action': return 'success';
        case 'error': return 'danger';
        case 'info': return 'info';
        default: return 'secondary';
    }
}

function showAlert(message, type) {
    const alertDiv = document.createElement('div');
    alertDiv.className = `alert alert-${type} alert-dismissible fade show`;
    alertDiv.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    
    document.body.insertBefore(alertDiv, document.body.firstChild);
    
    // 3秒后自动消失
    setTimeout(() => {
        if (alertDiv.parentNode) {
            alertDiv.parentNode.removeChild(alertDiv);
        }
    }, 3000);
}

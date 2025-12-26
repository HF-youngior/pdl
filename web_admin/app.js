// API基础URL
// 支持通过环境变量配置，默认使用 localhost:8080
// 在部署时可以通过设置 window.API_BASE_URL 来覆盖
// 例如: <script>window.API_BASE_URL = 'http://192.168.1.100:8080/api';</script>
const API_BASE_URL = (typeof window !== 'undefined' && window.API_BASE_URL) 
  ? window.API_BASE_URL 
  : 'https://localhost:8080/api';

// 是否启用 Web 端通知中心（默认禁用，可通过 window.ENABLE_WEB_NOTIFICATION_CENTER = true 启用）
const ENABLE_WEB_NOTIFICATION_CENTER = (typeof window !== 'undefined' && window.ENABLE_WEB_NOTIFICATION_CENTER !== undefined)
  ? !!window.ENABLE_WEB_NOTIFICATION_CENTER
  : false;

// 角色与部门配置
const ROLE_OPTIONS = [
    { value: 'admin', label: '管理员' },
    { value: 'founder', label: '创始人' },
    { value: 'department_head', label: '部门总监' },
    { value: 'team_leader', label: '团队长' },
    { value: 'employee', label: '员工' },
];

const ROLE_BADGE_COLORS = {
    admin: 'danger',
    founder: 'dark',
    department_head: 'warning',
    team_leader: 'info',
    employee: 'primary',
};

const DEPARTMENT_OPTIONS = [
    { id: 'dept-001', name: 'HR Department', label: '人事部' },
    { id: 'dept-002', name: 'Finance Department', label: '财务部' },
    { id: 'dept-003', name: 'Marketing Department', label: '宣传部' },
];

// 当前用户信息
let currentUser = null;
let currentTask = null;
let users = [];
let authToken = null;
let tasksList = [];
let importantItemsList = [];
let pendingNotifications = [];
let displayedNotificationIds = new Set(); // 跟踪已显示过的通知ID
let notificationModalInstance = null;
const notificationFilters = {
    keyword: '',
    startTime: '',
    endTime: ''
};

// 时间处理工具函数
const TARGET_TIMEZONE_LABEL = 'UTC+08:00 北京时间';
const TARGET_TZ_OFFSET_MINUTES = 8 * 60;

function padZero(value) {
    return value.toString().padStart(2, '0');
}

function parseLocalDateTime(value) {
    if (!value) return null;
    if (value instanceof Date) return new Date(value.getTime());
    if (typeof value === 'number') return new Date(value);
    if (typeof value !== 'string') return null;

    const normalized = value.trim();
    let parsed = new Date(normalized);

    if (Number.isNaN(parsed.getTime())) {
        const fallback = normalized.replace(' ', 'T');
        parsed = new Date(fallback);
    }

    if (Number.isNaN(parsed.getTime())) {
        return null;
    }

    return parsed;
}

function convertToBeijingDate(date) {
    const utcMillis = date.getTime();
    return new Date(utcMillis + TARGET_TZ_OFFSET_MINUTES * 60 * 1000);
}

function getBeijingDateParts(date) {
    const beijingDate = convertToBeijingDate(date);
    return {
        year: beijingDate.getUTCFullYear(),
        month: padZero(beijingDate.getUTCMonth() + 1),
        day: padZero(beijingDate.getUTCDate()),
        hours: padZero(beijingDate.getUTCHours()),
        minutes: padZero(beijingDate.getUTCMinutes()),
        seconds: padZero(beijingDate.getUTCSeconds())
    };
}

function formatTimeZoneLabel(date) {
    return TARGET_TIMEZONE_LABEL;
}

function formatDateTimeDisplay(value, fallback = '-') {
    const date = parseLocalDateTime(value);
    if (!date) return fallback;
    const parts = getBeijingDateParts(date);
    const formatted = `${parts.year}-${parts.month}-${parts.day} ${parts.hours}:${parts.minutes}`;
    return formatted;
}

function formatDateInputValue(value) {
    const date = parseLocalDateTime(value);
    if (!date) return '';
    const parts = getBeijingDateParts(date);
    return `${parts.year}-${parts.month}-${parts.day}T${parts.hours}:${parts.minutes}`;
}

// 统一清理模态框遗留的遮罩与滚动锁
function resetModalState() {
    try {
        document.querySelectorAll('.modal-backdrop').forEach(el => el.remove());
        document.body.classList.remove('modal-open');
        document.body.style.removeProperty('padding-right');
        document.body.style.removeProperty('overflow');
    } catch (_) {}
}

// 通知轮询相关变量
let notificationPollingInterval = null;
let lastNotificationCheckTime = null;

// 页面加载完成后初始化
document.addEventListener('DOMContentLoaded', function() {
    // 检查是否已登录
    checkAuthStatus();
    initUserFormOptions();
    if (ENABLE_WEB_NOTIFICATION_CENTER) {
        createNotificationCenterLauncher();
    } else {
        const btn = document.getElementById('notificationCenterLauncher');
        if (btn) btn.remove();
        stopNotificationPolling();
    }
    
    // 添加责任人选择事件监听器（编辑任务时更新部门显示）
    document.addEventListener('change', function(e) {
        if (e.target.id === 'editTaskAssignee') {
            const selectedUser = users.find(user => user.id === e.target.value);
            if (selectedUser) {
                const departmentDisplay = selectedUser.department_name || selectedUser.department || '';
                document.getElementById('editTaskDepartment').value = departmentDisplay;
            }
        }
    });
        
    // 详情页进度滑杆联动
    const progressEl = document.getElementById('detailProgressInput');
    if (progressEl) {
        progressEl.addEventListener('input', function() {
            const val = parseInt(this.value || '0');
            const bar = document.getElementById('taskProgressBar');
            const text = document.getElementById('taskProgressText');
            if (bar) {
                bar.style.width = `${val}%`;
                bar.className = `progress-bar ${getProgressBarColor(val)}`;
            }
            if (text) text.textContent = `${val}%`;
        });
        progressEl.disabled = false;
        progressEl.tabIndex = 0;
    }
});

// 检查新通知并显示弹窗
async function checkNotifications() {
    if (!ENABLE_WEB_NOTIFICATION_CENTER) return;
    if (!authToken || !currentUser) return;
    
    try {
        const response = await fetch(`${API_BASE_URL}/notifications`, {
            headers: getAuthHeaders()
        });
        
        if (!response.ok) return;
        
        const notifications = await response.json();
        
        // 只显示未读的通知
        const unreadNotifications = notifications.filter(n => !n.is_read);
        let hasNew = false;
        unreadNotifications.forEach(notification => {
            // 如果通知不在pendingNotifications中，且未显示过，则添加
            if (!pendingNotifications.some(item => item.id === notification.id) && 
                !displayedNotificationIds.has(notification.id)) {
                pendingNotifications.push(enhanceNotification(notification));
                hasNew = true;
            }
        });

        // 只在新通知且弹窗未打开时打开弹窗
        if (hasNew && !notificationModalInstance) {
            openNotificationCenterModal();
        }

        if (hasNew) {
            updateNotificationBadge();
        }
    } catch (error) {
        console.error('检查通知失败:', error);
    }
}

function enhanceNotification(notification) {
    return {
        ...notification,
        created_at_label: notification.created_at ? formatDateTimeDisplay(notification.created_at) : formatDateTimeDisplay(new Date()),
        deadline_label: notification.task_deadline ? formatDateTimeDisplay(notification.task_deadline) : '未设置',
        keyword_source: [
            notification.title || '',
            notification.task_title || '',
            notification.message || '',
            notification.notification_type || ''
        ].join(' ').toLowerCase()
    };
}

function createNotificationCenterLauncher() {
    if (document.getElementById('notificationCenterLauncher')) return;
    const button = document.createElement('button');
    button.id = 'notificationCenterLauncher';
    button.type = 'button';
    button.className = 'btn btn-warning position-fixed shadow';
    button.style.right = '20px';
    button.style.bottom = '20px';
    button.style.zIndex = '1050';
    button.innerHTML = `
        <i class="bi bi-bell-fill"></i>
        <span class="ms-1">通知</span>
        <span class="badge bg-danger ms-1" id="notificationLauncherBadge" style="display:none;">0</span>
    `;
    button.addEventListener('click', openNotificationCenterModal);
    document.body.appendChild(button);
}

async function updateNotificationBadge() {
    if (!ENABLE_WEB_NOTIFICATION_CENTER) return;
    const badge = document.getElementById('notificationLauncherBadge');
    if (!badge) return;
    
    try {
        // 获取所有未读通知的数量
        const response = await fetch(`${API_BASE_URL}/notifications`, {
            headers: getAuthHeaders()
        });
        
        if (response.ok) {
            const notifications = await response.json();
            const unreadCount = notifications.filter(n => !n.is_read).length;
            
            if (unreadCount > 0) {
                badge.style.display = 'inline-block';
                badge.textContent = unreadCount > 99 ? '99+' : unreadCount;
            } else {
                badge.style.display = 'none';
            }
        }
    } catch (error) {
        console.error('更新通知徽章失败:', error);
        // 如果获取失败，使用pendingNotifications作为后备
        const unreadCount = pendingNotifications.length;
        if (unreadCount > 0) {
            badge.style.display = 'inline-block';
            badge.textContent = unreadCount > 99 ? '99+' : unreadCount;
        } else {
            badge.style.display = 'none';
        }
    }
}

function openNotificationCenterModal() {
    if (!ENABLE_WEB_NOTIFICATION_CENTER) return;
    if (pendingNotifications.length === 0) return;
    if (notificationModalInstance) {
        refreshNotificationModalContent();
        return;
    }

    let modal = document.getElementById('notificationCenterModal');
    if (!modal) {
        modal = document.createElement('div');
        modal.id = 'notificationCenterModal';
        modal.className = 'modal fade';
        modal.setAttribute('data-bs-backdrop', 'true');
        modal.setAttribute('data-bs-keyboard', 'true');
        document.body.appendChild(modal);
    }

    modal.innerHTML = `
        <div class="modal-dialog modal-fullscreen-md-down modal-lg">
            <div class="modal-content">
                <div class="modal-header bg-info text-white">
                    <div class="d-flex align-items-center w-100 gap-3 flex-wrap">
                        <h5 class="modal-title mb-0">
                            <i class="bi bi-bell-fill"></i> 通知中心
                        </h5>
                        <div class="d-flex align-items-center gap-2 flex-wrap">
                            <input type="text" id="notificationSearchInput" class="form-control form-control-sm" placeholder="搜索标题/内容">
                            <input type="datetime-local" id="notificationSearchStart" class="form-control form-control-sm">
                            <input type="datetime-local" id="notificationSearchEnd" class="form-control form-control-sm">
                            <button class="btn btn-sm btn-light" id="notificationSearchReset">重置</button>
                        </div>
                    </div>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body notification-modal-body" style="max-height:70vh; overflow:auto;">
                    ${renderNotificationCards()}
                </div>
                <div class="modal-footer d-flex justify-content-between">
                    <div>
                        <button class="btn btn-outline-danger btn-sm" id="notificationDeleteAll">删除全部</button>
                        <button class="btn btn-outline-secondary btn-sm" id="notificationMarkAllRead">全部已读</button>
                    </div>
                    <button class="btn btn-secondary" data-bs-dismiss="modal">关闭</button>
                </div>
            </div>
        </div>
    `;

    modal.removeEventListener('click', handleNotificationModalAction, true);
    modal.addEventListener('click', handleNotificationModalAction, true);
    modal.querySelector('#notificationSearchInput').addEventListener('input', handleNotificationSearchInput);
    modal.querySelector('#notificationSearchStart').addEventListener('change', handleNotificationSearchInput);
    modal.querySelector('#notificationSearchEnd').addEventListener('change', handleNotificationSearchInput);
    modal.querySelector('#notificationSearchReset').addEventListener('click', resetNotificationSearchFilters);
    modal.querySelector('#notificationMarkAllRead').addEventListener('click', markAllNotificationsAsRead);

    notificationModalInstance = bootstrap.Modal.getInstance(modal) || new bootstrap.Modal(modal);
    notificationModalInstance.show();
    
    // 标记所有当前通知为已显示
    pendingNotifications.forEach(n => {
        displayedNotificationIds.add(n.id);
    });
    
    modal.addEventListener('hidden.bs.modal', () => {
        notificationModalInstance = null;
    });
}

function renderNotificationCards() {
    const list = applyNotificationFilters();
    if (list.length === 0) {
        return '<p class="text-muted mb-0">当前没有满足条件的通知。</p>';
    }

    return list.map((notification, index) => `
        <div class="border rounded p-3 mb-3 notification-card" data-notification-id="${notification.id}">
            <div class="d-flex justify-content-between align-items-center mb-2 flex-wrap gap-2">
                <div>
                    <strong>${notification.title || notification.task_title || `通知 ${index + 1}`}</strong>
                    <div class="text-muted small">发送时间：${notification.created_at_label}</div>
                </div>
                <span class="badge bg-info text-dark">${notification.notification_type || '通知'}</span>
            </div>
            <div class="mb-2">
                <p class="mb-1">${notification.message || '您有新的通知'}</p>
                <div class="text-muted small">截止时间：${notification.deadline_label}</div>
                ${notification.priority ? `<div class="text-muted small">优先级：${notification.priority}</div>` : ''}
                ${notification.status ? `<div class="text-muted small">当前状态：${notification.status}</div>` : ''}
                ${notification.from_user_name ? `<div class="text-muted small">来自：${notification.from_user_name}</div>` : ''}
            </div>
            <div class="d-flex flex-wrap gap-2">
                <button class="btn btn-sm btn-outline-primary" data-notification-action="view" data-notification-id="${notification.id}" data-notification-task-id="${notification.task_id || ''}">
                    查看任务
                </button>
                <button class="btn btn-sm btn-outline-secondary" data-notification-action="later" data-notification-id="${notification.id}">
                    稍后处理
                </button>
                <button class="btn btn-sm btn-success" data-notification-action="done" data-notification-id="${notification.id}">
                    已处理
                </button>
                <button class="btn btn-sm btn-outline-danger" data-notification-action="delete" data-notification-id="${notification.id}">
                    删除
                </button>
            </div>
        </div>
    `).join('');
}

function applyNotificationFilters() {
    const keyword = notificationFilters.keyword.trim().toLowerCase();
    const start = notificationFilters.startTime ? new Date(notificationFilters.startTime) : null;
    const end = notificationFilters.endTime ? new Date(notificationFilters.endTime) : null;

    return pendingNotifications
        .filter(notification => {
            if (keyword && !notification.keyword_source.includes(keyword)) {
                return false;
            }
            if (start && notification.created_at && new Date(notification.created_at) < start) {
                return false;
            }
            if (end && notification.created_at && new Date(notification.created_at) > end) {
                return false;
            }
            return true;
        })
        .sort((a, b) => {
            const aTime = a.created_at ? new Date(a.created_at).getTime() : 0;
            const bTime = b.created_at ? new Date(b.created_at).getTime() : 0;
            return bTime - aTime;
        });
}

function handleNotificationSearchInput(event) {
    const target = event.target;
    if (target.id === 'notificationSearchInput') {
        notificationFilters.keyword = target.value;
    } else if (target.id === 'notificationSearchStart') {
        notificationFilters.startTime = target.value;
    } else if (target.id === 'notificationSearchEnd') {
        notificationFilters.endTime = target.value;
    }
    refreshNotificationModalContent();
}

function resetNotificationSearchFilters() {
    notificationFilters.keyword = '';
    notificationFilters.startTime = '';
    notificationFilters.endTime = '';
    const modal = document.getElementById('notificationCenterModal');
    if (modal) {
        modal.querySelector('#notificationSearchInput').value = '';
        modal.querySelector('#notificationSearchStart').value = '';
        modal.querySelector('#notificationSearchEnd').value = '';
    }
    refreshNotificationModalContent();
}

function refreshNotificationModalContent() {
    const container = document.querySelector('#notificationCenterModal .notification-modal-body');
    if (!container) return;
    container.innerHTML = renderNotificationCards();
}

// 标记通知为已读
async function markNotificationAsRead(notificationId) {
    try {
        const response = await fetch(`${API_BASE_URL}/notifications/${notificationId}/read`, {
            method: 'PUT',
            headers: getAuthHeaders()
        });
        return response.ok;
    } catch (error) {
        console.error('标记通知已读失败:', error);
        return false;
    }
}

async function deleteNotification(notificationId) {
    try {
        const response = await fetch(`${API_BASE_URL}/notifications/${notificationId}`, {
            method: 'DELETE',
            headers: getAuthHeaders()
        });
        return response.ok;
    } catch (error) {
        console.error('删除通知失败:', error);
        return false;
    }
}

async function deleteAllNotifications() {
    if (pendingNotifications.length === 0) return;
    
    if (!confirm(`确定要删除所有 ${pendingNotifications.length} 条通知吗？此操作不可恢复。`)) {
        return;
    }
    
    try {
        let successCount = 0;
        let failCount = 0;
        
        for (const notification of pendingNotifications) {
            const success = await deleteNotification(notification.id);
            if (success) {
                successCount++;
                displayedNotificationIds.delete(notification.id);
            } else {
                failCount++;
            }
        }
        
        pendingNotifications = [];
        updateNotificationBadge();
        refreshNotificationModalContent();
        
        if (failCount > 0) {
            alert(`已删除 ${successCount} 条通知，${failCount} 条删除失败`);
        } else {
            alert(`已删除 ${successCount} 条通知`);
        }
    } catch (error) {
        console.error('批量删除通知失败:', error);
        alert('删除通知时出错');
    }
}

async function markAllNotificationsAsRead() {
    try {
        const response = await fetch(`${API_BASE_URL}/notifications/mark-all-read`, {
            method: 'PUT',
            headers: getAuthHeaders(),
            body: JSON.stringify({
                notification_ids: pendingNotifications.map(item => item.id)
            })
        });
        if (response.ok) {
            // 标记为已读后，通知仍在通知栏中，只是状态变为已读
            pendingNotifications.forEach(n => n.is_read = true);
            updateNotificationBadge();
            refreshNotificationModalContent();
        }
    } catch (error) {
        console.error('批量标记通知已读失败:', error);
    }
}

async function handleNotificationModalAction(event) {
    const button = event.target.closest('[data-notification-action]');
    if (!button) return;

    const action = button.dataset.notificationAction;
    const notificationId = button.dataset.notificationId;
    const taskId = button.dataset.notificationTaskId;
    if (action === 'view') {
        if (taskId) {
            await viewTaskDetail(taskId);
        }
        if (await markNotificationAsRead(notificationId)) {
            removeNotificationFromQueue(notificationId);
        }
    } else if (action === 'done') {
        if (await markNotificationAsRead(notificationId)) {
            removeNotificationFromQueue(notificationId);
        }
    } else if (action === 'later') {
        // 稍后处理：只关闭弹窗，不标记已读，通知仍在通知栏中
        const modalInstance = bootstrap.Modal.getInstance(document.getElementById('notificationCenterModal'));
        if (modalInstance) modalInstance.hide();
        return;
    } else if (action === 'delete') {
        if (await deleteNotification(notificationId)) {
            removeNotificationFromQueue(notificationId);
            displayedNotificationIds.delete(notificationId);
        }
    }

    refreshNotificationModalContent();
    updateNotificationBadge();

    if (pendingNotifications.length === 0) {
        const modalInstance = bootstrap.Modal.getInstance(document.getElementById('notificationCenterModal'));
        if (modalInstance) modalInstance.hide();
    }
}

function removeNotificationFromQueue(notificationId) {
    pendingNotifications = pendingNotifications.filter(item => item.id !== notificationId);
}

// 启动通知轮询
function startNotificationPolling() {
    if (!ENABLE_WEB_NOTIFICATION_CENTER) return;
    // 清除之前的轮询
    if (notificationPollingInterval) {
        clearInterval(notificationPollingInterval);
    }
    
    // 立即检查一次
    checkNotifications();
    
    // 每5秒检查一次新通知
    notificationPollingInterval = setInterval(checkNotifications, 5000);
}

// 停止通知轮询
function stopNotificationPolling() {
    if (notificationPollingInterval) {
        clearInterval(notificationPollingInterval);
        notificationPollingInterval = null;
    }
}

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
            
            // 启动通知轮询
            startNotificationPolling();
            
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
            
            // 启动通知轮询
            startNotificationPolling();
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
    // 停止通知轮询
    stopNotificationPolling();
    pendingNotifications = [];
    updateNotificationBadge();
    const modalEl = document.getElementById('notificationCenterModal');
    if (modalEl) {
        const modalInstance = bootstrap.Modal.getInstance(modalEl);
        if (modalInstance) modalInstance.hide();
    }
    
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
        
        // 控制"向上邀约"按钮的显示：admin用户不显示，其他用户显示
        const requestButton = document.getElementById('requestButton');
        if (requestButton) {
            if (currentUser.role === 'admin') {
                requestButton.style.display = 'none';
            } else {
                requestButton.style.display = 'inline-block';
            }
        }
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
    const totalUsersEl = document.getElementById('totalUsers');
    const totalImportantEl = document.getElementById('totalImportantItems');
    const pendingTasksEl = document.getElementById('pendingTasks');
    const todayLogsEl = document.getElementById('todayLogs');

    if (!authToken) {
        totalUsersEl.textContent = '--';
        totalImportantEl.textContent = '--';
        pendingTasksEl.textContent = '--';
        todayLogsEl.textContent = '--';
        return;
    }

    try {
        const response = await fetch(`${API_BASE_URL}/admin/dashboard-stats`, {
            headers: getAuthHeaders()
        });

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }

        const data = await response.json();
        totalUsersEl.textContent = data.totalUsers ?? '0';
        totalImportantEl.textContent = data.totalImportantItems ?? '0';
        pendingTasksEl.textContent = data.pendingTasks ?? '0';
        todayLogsEl.textContent = data.todayLogs ?? '0';
    } catch (error) {
        console.error('加载仪表板数据失败:', error);
        totalUsersEl.textContent = '--';
        totalImportantEl.textContent = '--';
        pendingTasksEl.textContent = '--';
        todayLogsEl.textContent = '--';
        showAlert('加载仪表板数据失败，请检查网络或登录状态', 'danger');
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
        renderUsersTable();
    } catch (error) {
        console.error('加载用户列表失败:', error);
        tbody.innerHTML = '<tr><td colspan="7" class="text-center text-danger">加载失败: ' + error.message + '</td></tr>';
        showAlert('加载用户列表失败: ' + error.message, 'danger');
    }
}

function renderUsersTable() {
    const tbody = document.getElementById('usersTableBody');
    if (!tbody) return;
    
    const keyword = (document.getElementById('userSearchInput')?.value || '').trim().toLowerCase();
    const filtered = keyword
        ? users.filter(user => {
            const departmentLabel = user.department_name || getDepartmentLabel(user.department_id) || user.department || '';
            return [
                user.username,
                user.name,
                user.position,
                departmentLabel
            ].some(field => (field || '').toLowerCase().includes(keyword));
        })
        : users;
    
    tbody.innerHTML = '';
    
    if (!filtered.length) {
        tbody.innerHTML = `<tr><td colspan="7" class="text-center text-muted">${keyword ? '没有匹配的用户' : '暂无用户数据'}</td></tr>`;
        return;
    }
    
    filtered.forEach(user => {
        const departmentLabel = user.department_name || getDepartmentLabel(user.department_id) || user.department || '-';
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${user.username}</td>
            <td>${user.name}</td>
            <td>${user.position}</td>
            <td>${departmentLabel}</td>
            <td><span class="badge bg-${getRoleBadgeColor(user.role)}">${getRoleDisplay(user.role)}</span></td>
            <td>${user.last_login_at ? formatDateTimeDisplay(user.last_login_at) : '从未登录'}</td>
            <td>
                <button class="btn btn-sm btn-outline-primary" onclick="showEditUserModal('${user.id}')">
                    <i class="bi bi-pencil"></i>
                </button>
                <button class="btn btn-sm btn-outline-danger" onclick="deleteUser('${user.id}')">
                    <i class="bi bi-trash"></i>
                </button>
            </td>
        `;
        tbody.appendChild(row);
    });
}

function handleUserSearch() {
    renderUsersTable();
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
        
        importantItemsList = await response.json();
        renderImportantItemsTable();
    } catch (error) {
        console.error('加载重要事项列表失败:', error);
        showAlert('加载重要事项列表失败', 'danger');
    }
}

function renderImportantItemsTable() {
    const tbody = document.getElementById('importantItemsTableBody');
    if (!tbody) return;
    
    const keyword = (document.getElementById('importantSearchInput')?.value || '').trim().toLowerCase();
    const filtered = keyword
        ? importantItemsList.filter(item =>
            [item.title, item.description, item.department, item.priority, item.status]
                .some(field => (field || '').toString().toLowerCase().includes(keyword))
          )
        : importantItemsList;
    
    tbody.innerHTML = '';
    
    if (!filtered.length) {
        tbody.innerHTML = `<tr><td colspan="7" class="text-center text-muted">${keyword ? '没有匹配的事项' : '暂无数据'}</td></tr>`;
        return;
    }
    
    filtered.forEach(item => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${item.title}</td>
            <td>${item.description || '-'}</td>
            <td><span class="badge bg-${getPriorityBadgeColor(item.priority)}">${item.priority}</span></td>
            <td><span class="badge bg-${getStatusBadgeColor(item.status)}">${item.status}</span></td>
            <td>${item.department || '-'}</td>
            <td>${formatDateTimeDisplay(item.deadline)}</td>
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
}

function handleImportantSearch() {
    renderImportantItemsTable();
}

// 加载任务列表
async function loadTasks() {
    const tbody = document.getElementById('tasksTableBody');
    if (tbody) {
        tbody.innerHTML = '<tr><td colspan="9" class="text-center"><i class="bi bi-hourglass-split"></i> 加载中...</td></tr>';
    }

    try {
        const response = await fetch(`${API_BASE_URL}/tasks`, {
            headers: getAuthHeaders()
        });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        tasksList = await response.json();
        renderTasksTable();
    } catch (error) {
        console.error('加载任务列表失败:', error);
        if (tbody) {
            tbody.innerHTML = '<tr><td colspan="9" class="text-center text-danger">加载失败: ' + error.message + '</td></tr>';
        }
        showAlert('加载任务列表失败', 'danger');
    }
}

function renderTasksTable() {
    const tbody = document.getElementById('tasksTableBody');
    if (!tbody) return;
    
    const keyword = (document.getElementById('taskSearchInput')?.value || '').trim().toLowerCase();
    const filtered = keyword
        ? tasksList.filter(task => {
            const departmentDisplay = task.department || task.department_name || '';
            return [
                task.title,
                task.description,
                task.assignee_name,
                departmentDisplay,
                task.priority,
                task.status
            ].some(field => (field || '').toString().toLowerCase().includes(keyword));
        })
        : tasksList;
    
    // 统计任务数量（基于当前展示列表）
    const totalTasks = filtered.length;
    const inProgressTasks = filtered.filter(task => task.status === 'in_progress' || task.status === 'pending').length;
    const completedTasks = filtered.filter(task => task.status === 'completed').length;
    const now = new Date();
    const overdueTasks = filtered.filter(task => {
        const deadlineDate = parseLocalDateTime(task.deadline);
        if (!deadlineDate) return false;
        return deadlineDate < now && task.status !== 'completed';
    }).length;
    
    document.getElementById('totalTasksCount').textContent = totalTasks;
    document.getElementById('inProgressTasksCount').textContent = inProgressTasks;
    document.getElementById('completedTasksCount').textContent = completedTasks;
    document.getElementById('overdueTasksCount').textContent = overdueTasks;
    
    tbody.innerHTML = '';
    
    if (!filtered.length) {
        tbody.innerHTML = `<tr><td colspan="9" class="text-center text-muted">${keyword ? '没有匹配的任务' : '暂无任务数据'}</td></tr>`;
        return;
    }
    
    filtered.forEach(task => {
        const row = document.createElement('tr');
        const progress = calculateTaskProgress(task);
        const deadlineDate = parseLocalDateTime(task.deadline);
        const isOverdue = deadlineDate && deadlineDate < now && task.status !== 'completed';
        
        const isRequestTask = task.is_request === true || task.is_request === 1;
        const isAssignee = currentUser && (task.assignee_id === currentUser.id || task.assignee_name === currentUser.name);
        const isProcessed = task.request_response;
        
        let actionButtons = '';
        if (isRequestTask) {
            if (isAssignee && !isProcessed) {
                actionButtons = `
                    <button class="btn btn-sm btn-success" onclick="showHandleRequestModal('${task.id}')" title="处理邀约">
                        <i class="bi bi-check-circle"></i> 处理邀约
                    </button>
                `;
            } else {
                actionButtons = `
                    <button class="btn btn-sm btn-outline-info" onclick="viewTaskDetail('${task.id}')" title="查看详情">
                        <i class="bi bi-eye"></i> 查看详情
                    </button>
                `;
            }
        } else {
            actionButtons = `
                <button class="btn btn-sm btn-outline-info" onclick="viewTaskDetail('${task.id}')" title="查看详情">
                    <i class="bi bi-eye"></i>
                </button>
                <button class="btn btn-sm btn-outline-primary" onclick="editTask('${task.id}')" title="编辑">
                    <i class="bi bi-pencil"></i>
                </button>
                <button class="btn btn-sm btn-outline-danger" onclick="deleteTask('${task.id}')" title="删除">
                    <i class="bi bi-trash"></i>
                </button>
            `;
        }
        
        row.innerHTML = `
            <td>
                <div class="d-flex align-items-center">
                    <div class="me-2" style="width: 12px; height: 12px; min-width: 12px; min-height: 12px; max-width: 12px; max-height: 12px; background-color: ${task.color || '#4CAF50'}; border-radius: 50%; flex-shrink: 0;"></div>
                    ${isRequestTask ? '<span class="badge bg-danger me-2" style="font-size: 0.7rem;">邀约</span>' : ''}
                    <span class="${isOverdue ? 'text-danger fw-bold' : ''}">${task.title}</span>
                </div>
            </td>
            <td>${task.description ? (task.description.length > 50 ? task.description.substring(0, 50) + '...' : task.description) : '-'}</td>
            <td>${task.assignee_name}</td>
            <td>${task.department || task.department_name || '-'}</td>
            <td><span class="badge bg-${getPriorityBadgeColor(task.priority)}">${getPriorityText(task.priority)}</span></td>
            <td><span class="badge bg-${getStatusBadgeColor(task.status)}">${isRequestTask && !isProcessed && task.status === 'pending' ? '待处理' : getStatusText(task.status)}</span></td>
            <td>
                <div class="progress" style="height: 20px;">
                    <div class="progress-bar ${getProgressBarColor(progress)}" role="progressbar" style="width: ${progress}%">
                        ${progress}%
                    </div>
                </div>
            </td>
            <td class="${isOverdue ? 'text-danger fw-bold' : ''}">${formatDateTimeDisplay(task.deadline)}</td>
            <td>
                ${actionButtons}
            </td>
        `;
        tbody.appendChild(row);
    });
}

function handleTaskSearch() {
    renderTasksTable();
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
                <td>${formatDateTimeDisplay(log.created_at)}</td>
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

// 初始化用户表单选项
function initUserFormOptions() {
    populateDepartmentSelect('department');
    populateRoleSelect('role');
    populateDepartmentSelect('editDepartment');
    populateRoleSelect('editRole');
}

function populateDepartmentSelect(selectId) {
    const select = document.getElementById(selectId);
    if (!select) return;
    select.innerHTML = '<option value="">选择部门</option>';
    DEPARTMENT_OPTIONS.forEach(dept => {
        const option = document.createElement('option');
        option.value = dept.id;
        option.textContent = `${dept.label} (${dept.name})`;
        select.appendChild(option);
    });
}

function populateRoleSelect(selectId) {
    const select = document.getElementById(selectId);
    if (!select) return;
    select.innerHTML = '<option value="">选择角色</option>';
    ROLE_OPTIONS.forEach(role => {
        const option = document.createElement('option');
        option.value = role.value;
        option.textContent = role.label;
        select.appendChild(option);
    });
}

function getDepartmentLabel(deptId) {
    const match = DEPARTMENT_OPTIONS.find(d => d.id === deptId);
    return match ? `${match.label}` : null;
}

function getDepartmentIdFromName(name) {
    if (!name) return '';
    const match = DEPARTMENT_OPTIONS.find(
        d => d.id === name || d.name === name || d.label === name
    );
    return match ? match.id : '';
}

function getRoleDisplay(role) {
    const match = ROLE_OPTIONS.find(r => r.value === role);
    return match ? match.label : role || '未知';
}

// 显示添加用户模态框
function showAddUserModal() {
    const form = document.getElementById('addUserForm');
    form.reset();
    const modal = new bootstrap.Modal(document.getElementById('addUserModal'));
    modal.show();
}

// 添加用户
async function addUser() {
    const form = document.getElementById('addUserForm');
    if (!form.checkValidity()) {
        form.reportValidity();
        return;
    }
    
    const payload = {
        username: document.getElementById('username').value.trim(),
        password: document.getElementById('password').value,
        name: document.getElementById('name').value.trim(),
        position: document.getElementById('position').value.trim(),
        department_id: document.getElementById('department').value,
        role: document.getElementById('role').value,
    };

    if (!payload.department_id || !payload.role) {
        showAlert('请选择完整的部门与角色', 'warning');
        return;
    }

    try {
        const response = await fetch(`${API_BASE_URL}/users`, {
            method: 'POST',
            headers: getAuthHeaders(),
            body: JSON.stringify(payload),
        });

        if (response.ok || response.status === 201) {
            showAlert('用户添加成功', 'success');
            bootstrap.Modal.getInstance(document.getElementById('addUserModal')).hide();
            form.reset();
            loadUsers();
        } else {
            const error = await response.json().catch(() => ({}));
            showAlert(error.message || error.error || '添加用户失败', 'danger');
        }
    } catch (error) {
        console.error('添加用户失败:', error);
        showAlert('添加用户失败: ' + error.message, 'danger');
    }
}

function showEditUserModal(userId) {
    const user = users.find(u => u.id === userId);
    if (!user) {
        showAlert('未找到该用户', 'warning');
        return;
    }
    document.getElementById('editUserId').value = user.id;
    document.getElementById('editUsername').value = user.username;
    document.getElementById('editName').value = user.name || '';
    document.getElementById('editPosition').value = user.position || '';
    const deptValue = user.department_id || getDepartmentIdFromName(user.department_name || user.department) || '';
    document.getElementById('editDepartment').value = deptValue;
    document.getElementById('editRole').value = user.role || '';
    document.getElementById('editPassword').value = '';
    const modal = new bootstrap.Modal(document.getElementById('editUserModal'));
    modal.show();
}

async function updateUser() {
    const form = document.getElementById('editUserForm');
    if (!form.checkValidity()) {
        form.reportValidity();
        return;
    }
    const userId = document.getElementById('editUserId').value;
    if (!userId) {
        showAlert('未找到用户ID', 'danger');
        return;
    }

    const payload = {
        name: document.getElementById('editName').value.trim(),
        position: document.getElementById('editPosition').value.trim(),
        department_id: document.getElementById('editDepartment').value,
        role: document.getElementById('editRole').value,
    };
    const newPassword = document.getElementById('editPassword').value;
    if (newPassword) {
        payload.password = newPassword;
    }

    try {
        const response = await fetch(`${API_BASE_URL}/users/${userId}`, {
            method: 'PUT',
            headers: getAuthHeaders(),
            body: JSON.stringify(payload),
        });
        if (response.ok) {
            showAlert('用户信息已更新', 'success');
            bootstrap.Modal.getInstance(document.getElementById('editUserModal')).hide();
            loadUsers();
        } else {
            const error = await response.json().catch(() => ({}));
            showAlert(error.message || error.error || '更新用户失败', 'danger');
        }
    } catch (error) {
        console.error('更新用户失败:', error);
        showAlert('更新用户失败: ' + error.message, 'danger');
    }
}

async function deleteUser(userId) {
    if (!confirm('确定要删除该用户吗？此操作不可撤销。')) {
        return;
    }
    try {
        const response = await fetch(`${API_BASE_URL}/users/${userId}`, {
            method: 'DELETE',
            headers: getAuthHeaders(),
        });
        if (response.ok) {
            showAlert('用户已删除', 'success');
            loadUsers();
        } else {
            const error = await response.json().catch(() => ({}));
            showAlert(error.message || error.error || '删除用户失败', 'danger');
        }
    } catch (error) {
        console.error('删除用户失败:', error);
        showAlert('删除用户失败: ' + error.message, 'danger');
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
        document.getElementById('editImportantItemDeadline').value = formatDateInputValue(item.deadline);
        
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
    // 使用复选框列表填充可选责任人
    const listContainer = document.getElementById('taskAssigneeList');
    if (listContainer) {
        listContainer.innerHTML = '';

        users.forEach(user => {
            const departmentDisplay = user.department_name || user.department || '未知部门';
            const item = document.createElement('div');
            item.className = 'form-check';
            item.innerHTML = `
                <input class="form-check-input" type="checkbox" value="${user.id}" id="taskAssignee_${user.id}">
                <label class="form-check-label" for="taskAssignee_${user.id}">
                    ${user.name} (${departmentDisplay})
                </label>
            `;
            listContainer.appendChild(item);
        });
    }

    // 部门信息说明（多负责人时按员工所属部门自动设置）
    const deptInput = document.getElementById('taskDepartment');
    if (deptInput) {
        deptInput.value = '将根据员工所属部门自动设置';
    }

    // 设置默认时间
    const now = new Date();
    const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    document.getElementById('taskStartTime').value = formatDateInputValue(now);
    document.getElementById('taskDeadline').value = formatDateInputValue(tomorrow);

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
    
    // 从复选框列表中收集选中的责任人
    const checked = document.querySelectorAll('#taskAssigneeList input[type="checkbox"]:checked');
    const selectedUserIds = Array.from(checked).map(cb => cb.value);

    if (!selectedUserIds.length) {
        showAlert('请至少选择一名责任人', 'warning');
        return;
    }

    // 校验所有选中用户是否存在且有部门信息
    const selectedUsers = [];
    for (const userId of selectedUserIds) {
        const user = users.find(u => u.id === userId);
        if (!user) {
            showAlert('未找到选中的用户', 'danger');
            return;
        }
        if (!user.department_id) {
            showAlert('部分用户缺少部门信息，请检查用户配置', 'danger');
            return;
        }
        selectedUsers.push(user);
    }

    // 弹出确认负责人弹窗
    const isSingle = selectedUsers.length === 1;
    const titleWord = isSingle ? '这名' : '这些';
    const namesText = selectedUsers.map(user => {
        const dept = user.department_name || user.department || '未知部门';
        return `${user.name} (${dept})`;
    }).join('\n');

    const confirmMessage = `确认选择${titleWord}员工为负责人？\n\n${namesText}`;
    if (!window.confirm(confirmMessage)) {
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
    
    const parentHidden = document.getElementById('parentTaskId');
    const commonData = {
        title: document.getElementById('taskTitle').value,
        description: document.getElementById('taskDescription').value || '',
        priority: document.getElementById('taskPriority').value || 'p1',
        start_time: startTime ? formatDateTime(startTime) : null,
        end_time: deadline ? formatDateTime(deadline) : null,
        deadline: deadline ? formatDateTime(deadline) : null,
        location: document.getElementById('taskLocation').value || null,
        is_all_day: isAllDay,
        parent_task_id: parentHidden && parentHidden.value ? parentHidden.value : null
    };
    
    let successCount = 0;
    let failCount = 0;

    for (const user of selectedUsers) {
        const taskData = {
            ...commonData,
            assignee_id: user.id,
            department_id: user.department_id
        };

        try {
            const response = await fetch(`${API_BASE_URL}/tasks`, {
                method: 'POST',
                headers: getAuthHeaders(),
                body: JSON.stringify(taskData)
            });

            if (response.ok || response.status === 201) {
                successCount++;
            } else {
                failCount++;
            }
        } catch (error) {
            console.error('发布任务失败:', error);
            failCount++;
        }
    }

    if (successCount === 0) {
        showAlert('发布任务失败，请稍后重试', 'danger');
        return;
    }

    const isSubtask = !!(parentHidden && parentHidden.value);
    if (selectedUserIds.length > 1) {
        const msg = `已为 ${successCount} 名员工发布${isSubtask ? '子任务' : '任务'}${failCount > 0 ? `，${failCount} 个失败` : ''}！`;
        showAlert(msg, failCount > 0 ? 'warning' : 'success');
    } else {
        showAlert(`${isSubtask ? '子任务' : '任务'}发布成功！`, 'success');
    }

    // 关闭模态框
    const addInst = bootstrap.Modal.getInstance(document.getElementById('addTaskModal'));
    if (addInst) addInst.hide();
    resetModalState();

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

    // 立即刷新任务列表，确保数据是最新的
    await loadTasks();

    // 如果是从详情页创建的子任务，刷新子任务列表
    if (isSubtask && currentTask && currentTask.id) {
        await loadTaskSubtasks(currentTask.id);
    }
}

// 显示向上邀约模态框
function showRequestModal() {
    // 角色等级函数
    function roleRank(role) {
        switch(role) {
            case 'founder':
            case 'admin':
                return 5;
            case 'department_head':
                return 4;
            case 'team_leader':
                return 3;
            case 'employee':
            default:
                return 1;
        }
    }
    
    // 填充接收人列表（只显示同级或上级）
    const assigneeSelect = document.getElementById('requestAssignee');
    assigneeSelect.innerHTML = '<option value="">选择接收人</option>';
    
    if (currentUser) {
        const currentUserRank = roleRank(currentUser.role);
        
        users.forEach(user => {
            // 排除自己
            if (user.id === currentUser.id) return;
            
            // 只显示同级或上级（角色等级 >= 当前用户等级）
            const userRank = roleRank(user.role);
            if (userRank >= currentUserRank) {
                const option = document.createElement('option');
                option.value = user.id;
                const departmentDisplay = user.department_name || user.department || '未知部门';
                option.textContent = `${user.name} (${departmentDisplay} · ${user.role})`;
                assigneeSelect.appendChild(option);
            }
        });
    }
    
    // 填充关联任务列表（只显示非邀约任务）
    const relatedTaskSelect = document.getElementById('requestRelatedTask');
    relatedTaskSelect.innerHTML = '<option value="">无关联任务</option>';
    
    // 需要先加载任务列表
    fetch(`${API_BASE_URL}/tasks`, {
        headers: getAuthHeaders()
    })
    .then(response => response.json())
    .then(tasks => {
        tasks.forEach(task => {
            // 只显示非邀约任务
            if (!task.is_request) {
                const option = document.createElement('option');
                option.value = task.id;
                option.textContent = `${task.title} (${task.assignee_name})`;
                relatedTaskSelect.appendChild(option);
            }
        });
    })
    .catch(error => {
        console.error('加载任务列表失败:', error);
    });
    
    // 设置默认期望回复时间（3天后）
    const now = new Date();
    const defaultDeadline = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);
    document.getElementById('requestDeadline').value = defaultDeadline.toISOString().slice(0, 16);
    
    // 重置表单
    document.getElementById('requestForm').reset();
    
    // 设置默认邀约时间为明天上午9点到下午5点
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const defaultStartTime = new Date(tomorrow.getFullYear(), tomorrow.getMonth(), tomorrow.getDate(), 9, 0);
    const defaultEndTime = new Date(tomorrow.getFullYear(), tomorrow.getMonth(), tomorrow.getDate(), 17, 0);
    
    document.getElementById('requestStartTime').value = defaultStartTime.toISOString().slice(0, 16);
    document.getElementById('requestEndTime').value = defaultEndTime.toISOString().slice(0, 16);
    document.getElementById('requestDeadline').value = defaultDeadline.toISOString().slice(0, 16);
    
    const modal = new bootstrap.Modal(document.getElementById('requestModal'));
    modal.show();
}

// 创建向上邀约请求
async function createRequest() {
    const form = document.getElementById('requestForm');
    
    // 检查表单验证
    if (!form.checkValidity()) {
        form.reportValidity();
        return;
    }
    
    const requestType = document.getElementById('requestType').value;
    const assigneeId = document.getElementById('requestAssignee').value;
    const description = document.getElementById('requestDescription').value.trim();
    const startTime = document.getElementById('requestStartTime').value;
    const endTime = document.getElementById('requestEndTime').value;
    const deadline = document.getElementById('requestDeadline').value;
    const relatedTaskId = document.getElementById('requestRelatedTask').value;
    
    if (!requestType || !assigneeId || !description || !startTime || !endTime) {
        showAlert('请填写所有必填项', 'warning');
        return;
    }
    
    // 验证结束时间不能早于开始时间
    if (new Date(endTime) < new Date(startTime)) {
        showAlert('结束时间不能早于开始时间', 'warning');
        return;
    }
    
    // 对于需要关联任务的请求类型，验证是否选择了关联任务
    const requiresRelatedTask = ['修改任务', '删除任务', '重新安排任务'];
    if (requiresRelatedTask.includes(requestType) && !relatedTaskId) {
        showAlert(`${requestType}类型的邀约请求必须关联一个任务`, 'warning');
        return;
    }
    
    // 格式化时间字段
    let formattedDeadline = null;
    if (deadline) {
        formattedDeadline = deadline.replace('T', ' ') + ':00';
    }
    
    const formattedStartTime = startTime.replace('T', ' ') + ':00';
    const formattedEndTime = endTime.replace('T', ' ') + ':00';
    
    const requestData = {
        request_type: requestType,
        assignee_id: assigneeId,
        description: description,
        deadline: formattedDeadline,
        request_start_time: formattedStartTime,
        request_end_time: formattedEndTime,
        related_task_id: relatedTaskId || null
    };
    
    try {
        const response = await fetch(`${API_BASE_URL}/tasks/request`, {
            method: 'POST',
            headers: getAuthHeaders(),
            body: JSON.stringify(requestData)
        });
        
        if (response.ok || response.status === 201) {
            showAlert('邀约请求发送成功！', 'success');
            
            // 关闭模态框
            const modal = bootstrap.Modal.getInstance(document.getElementById('requestModal'));
            if (modal) modal.hide();
            resetModalState();
            
            // 重置表单
            form.reset();
            
            // 立即刷新任务列表，确保数据是最新的
            await loadTasks();
        } else {
            const error = await response.json();
            showAlert(error.error || error.message || '发送邀约失败', 'danger');
        }
    } catch (error) {
        console.error('发送邀约失败:', error);
        showAlert('发送邀约失败: ' + error.message, 'danger');
    }
}

// 显示处理邀约模态框
async function showHandleRequestModal(taskId) {
    try {
        // 获取任务详情
        const response = await fetch(`${API_BASE_URL}/tasks/${taskId}`, {
            headers: getAuthHeaders()
        });
        
        if (!response.ok) {
            throw new Error('获取任务详情失败');
        }
        
        const task = await response.json();
        
        // 检查是否为邀约任务
        if (!task.is_request) {
            showAlert('此任务不是邀约任务', 'warning');
            return;
        }
        
        // 检查是否已处理
        if (task.request_response) {
            showAlert('此邀约请求已被处理', 'info');
            return;
        }
        
        // 填充模态框内容
        document.getElementById('handleRequestTaskId').value = taskId;
        document.getElementById('handleRequestTitle').textContent = task.title;
        document.getElementById('handleRequestType').textContent = task.request_type || '未知';
        document.getElementById('handleRequestDescription').textContent = task.description || '无';
        document.getElementById('handleRequestNotes').value = '';
        
        // 重置单选按钮为批准
        document.getElementById('approveAction').checked = true;
        document.getElementById('rejectAction').checked = false;
        
        // 显示模态框
        const modal = new bootstrap.Modal(document.getElementById('handleRequestModal'));
        modal.show();
    } catch (error) {
        console.error('加载任务详情失败:', error);
        showAlert('加载任务详情失败: ' + error.message, 'danger');
    }
}

// 处理邀约请求
async function handleRequest() {
    const taskId = document.getElementById('handleRequestTaskId').value;
    const action = document.querySelector('input[name="requestAction"]:checked').value;
    const notes = document.getElementById('handleRequestNotes').value.trim();
    
    if (!taskId || !action) {
        showAlert('请选择处理方式', 'warning');
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE_URL}/tasks/${taskId}/request-response`, {
            method: 'PUT',
            headers: getAuthHeaders(),
            body: JSON.stringify({
                action: action,
                notes: notes || null
            })
        });
        
        if (response.ok) {
            const result = await response.json();
            const actionText = action === 'approve' ? '批准' : '拒绝';
            
            // 关闭模态框
            const modal = bootstrap.Modal.getInstance(document.getElementById('handleRequestModal'));
            if (modal) modal.hide();
            resetModalState();
            
            // 显示成功消息
            showAlert(`邀约请求已${actionText}！任务状态已更新为已完成，进度已更新为100%。发送邀约的人已收到通知。`, 'success');
            
            // 立即刷新任务列表，确保数据是最新的
            await loadTasks();
        } else {
            const error = await response.json();
            showAlert(error.error || error.message || '处理邀约失败', 'danger');
        }
    } catch (error) {
        console.error('处理邀约失败:', error);
        showAlert('处理邀约失败: ' + error.message, 'danger');
    }
}

// 查看任务详情
async function viewTaskDetail(taskId) {
    try {
        resetModalState();
        const response = await fetch(`${API_BASE_URL}/tasks/${taskId}`, {
            headers: getAuthHeaders()
        });
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
        document.getElementById('detailTaskStartTime').textContent = currentTask.start_time ? formatDateTimeDisplay(currentTask.start_time, '未设置') : '未设置';
        document.getElementById('detailTaskDeadline').textContent = currentTask.deadline ? formatDateTimeDisplay(currentTask.deadline, '未设置') : '未设置';
        document.getElementById('detailTaskCreatedAt').textContent = currentTask.created_at ? formatDateTimeDisplay(currentTask.created_at, '未知') : '未知';
        document.getElementById('detailTaskCreatedBy').textContent = currentTask.created_by || '未知';
        
        // 更新进度条
        const progress = calculateTaskProgress(currentTask);
        const progressBar = document.getElementById('taskProgressBar');
        const progressText = document.getElementById('taskProgressText');
        
        // 对于已处理的邀约任务，隐藏进度条
        const progressCard = document.getElementById('progressCard');
        if (currentTask.is_request && currentTask.request_response) {
            if (progressCard) {
                progressCard.style.display = 'none';
            }
        } else {
            if (progressCard) {
                progressCard.style.display = 'block';
            }
            progressBar.style.width = `${progress}%`;
            progressBar.className = `progress-bar ${getProgressBarColor(progress)}`;
            progressText.textContent = `${progress}%`;
            const progressInput = document.getElementById('detailProgressInput');
            if (progressInput) {
                progressInput.value = progress;
                progressInput.disabled = false;
            }
        }
        
        // 判断是否为邀约任务
        const isRequestTask = currentTask.is_request === true || currentTask.is_request === 1;
        
        // 显示邀约处理结果（如果是邀约任务）
        const requestResponseSection = document.getElementById('requestResponseSection');
        if (isRequestTask && requestResponseSection) {
            requestResponseSection.style.display = 'block';
            
            // 显示请求类型
            const requestTypeEl = document.getElementById('detailRequestType');
            if (requestTypeEl) {
                requestTypeEl.textContent = currentTask.request_type || '未知';
            }
            
            // 显示处理结果
            const requestResponseEl = document.getElementById('detailRequestResponse');
            if (requestResponseEl) {
                if (currentTask.request_response) {
                    const responseText = currentTask.request_response === 'approve' ? '批准' : '拒绝';
                    const responseColor = currentTask.request_response === 'approve' ? 'success' : 'danger';
                    requestResponseEl.innerHTML = `<span class="badge bg-${responseColor}">${responseText}</span>`;
                } else {
                    requestResponseEl.innerHTML = '<span class="badge bg-warning">待处理</span>';
                }
            }
            
            // 显示处理备注（如果有）
            const requestNotesEl = document.getElementById('detailRequestNotes');
            const requestNotesRow = document.getElementById('detailRequestNotesRow');
            if (currentTask.special_notes && currentTask.special_notes.trim()) {
                if (requestNotesEl) {
                    requestNotesEl.textContent = currentTask.special_notes;
                }
                if (requestNotesRow) {
                    requestNotesRow.style.display = 'block';
                }
            } else {
                if (requestNotesRow) {
                    requestNotesRow.style.display = 'none';
                }
            }
        } else {
            if (requestResponseSection) {
                requestResponseSection.style.display = 'none';
            }
        }
        
        // 获取子任务和日志的卡片元素
        const subtasksCard = document.getElementById('subtasksCard');
        const logsCard = document.getElementById('logsCard');
        
        if (isRequestTask) {
            // 邀约任务：隐藏子任务和日志卡片
            if (subtasksCard) {
                subtasksCard.style.display = 'none';
            }
            if (logsCard) {
                logsCard.style.display = 'none';
            }
        } else {
            // 普通任务：显示子任务和日志卡片
            if (subtasksCard) {
                subtasksCard.style.display = 'block';
            }
            if (logsCard) {
                logsCard.style.display = 'block';
            }
            
            // 加载子任务列表
            await loadTaskSubtasks(taskId);
            
            // 加载关联日志
            await loadTaskLogs(taskId);
            
            // 显示创建子任务按钮
            const createBtn = document.getElementById('createSubtaskBtn');
            if (createBtn) {
                createBtn.style.display = 'inline-block';
            }
        }
        
        // 隐藏/显示操作按钮，对于已处理的邀约任务只显示编辑和删除按钮
        const editTaskBtn = document.querySelector('#taskDetailModal .btn-primary[onclick="editTask()"]');
        const saveProgressBtn = document.querySelector('#taskDetailModal .btn-warning[onclick="saveDetailProgress()"]');
        const completeTaskBtn = document.querySelector('#taskDetailModal .btn-success[onclick="completeTask()"]');
        const deleteTaskBtn = document.querySelector('#taskDetailModal .btn-danger[onclick="deleteTask()"]');
        
        if (isRequestTask && currentTask.request_response) {
            // 已处理的邀约任务：只显示编辑和删除按钮
            if (editTaskBtn) editTaskBtn.style.display = 'block';
            if (saveProgressBtn) saveProgressBtn.style.display = 'none';
            if (completeTaskBtn) completeTaskBtn.style.display = 'none';
            if (deleteTaskBtn) deleteTaskBtn.style.display = 'block';
        } else {
            // 普通任务或未处理的邀约任务：显示所有按钮
            if (editTaskBtn) editTaskBtn.style.display = 'block';
            if (saveProgressBtn) saveProgressBtn.style.display = 'block';
            if (completeTaskBtn) completeTaskBtn.style.display = 'block';
            if (deleteTaskBtn) deleteTaskBtn.style.display = 'block';
        }
        
        // 显示模态框
        const modal = new bootstrap.Modal(document.getElementById('taskDetailModal'));
        modal.show();
    } catch (error) {
        console.error('获取任务详情失败:', error);
        showAlert('获取任务详情失败: ' + (error.message || ''), 'danger');
    }
}

// 加载任务子任务列表
async function loadTaskSubtasks(taskId) {
    try {
        const response = await fetch(`${API_BASE_URL}/tasks?parent_task_id=${taskId}`, {
            headers: getAuthHeaders()
        });
        if (!response.ok) {
            throw new Error('获取子任务列表失败');
        }
        const subtasks = await response.json();
        
        const subtasksList = document.getElementById('taskSubtasksList');
        const createBtn = document.getElementById('createSubtaskBtn');
        
        if (subtasksList) {
            subtasksList.innerHTML = '';
            
            if (subtasks.length === 0) {
                subtasksList.innerHTML = '<p class="text-muted mb-0">无</p>';
            } else {
                subtasks.forEach(subtask => {
                    const subtaskItem = document.createElement('div');
                    subtaskItem.className = 'border-bottom pb-2 mb-2';
                    const progress = calculateTaskProgress(subtask);
                    subtaskItem.innerHTML = `
                        <div class="d-flex justify-content-between align-items-center">
                            <div class="flex-grow-1">
                                <h6 class="mb-1">${subtask.title}</h6>
                                <div class="d-flex align-items-center gap-3">
                                    <span class="badge bg-${getPriorityBadgeColor(subtask.priority)}">${getPriorityText(subtask.priority)}</span>
                                    <span class="badge bg-${getStatusBadgeColor(subtask.status)}">${getStatusText(subtask.status)}</span>
                                    <small class="text-muted">进度: ${progress}%</small>
                                </div>
                            </div>
                            <div>
                                <button class="btn btn-sm btn-outline-info" onclick="viewTaskDetail('${subtask.id}')" title="查看详情">
                                    <i class="bi bi-eye"></i>
                                </button>
                            </div>
                        </div>
                    `;
                    subtasksList.appendChild(subtaskItem);
                });
            }
        }
        
        // 显示创建子任务按钮（有权限的用户都可以创建子任务）
        if (createBtn) {
            createBtn.style.display = 'inline-block';
        }
    } catch (error) {
        console.error('加载子任务列表失败:', error);
        const subtasksList = document.getElementById('taskSubtasksList');
        if (subtasksList) {
            subtasksList.innerHTML = '<p class="text-muted mb-0">加载失败</p>';
        }
    }
}

// 加载任务关联的日志
async function loadTaskLogs(taskId) {
    try {
        const response = await fetch(`${API_BASE_URL}/logs?taskId=${taskId}`, {
            headers: getAuthHeaders()
        });
        const logs = await response.json();
        
        const logsList = document.getElementById('taskLogsList');
        logsList.innerHTML = '';
        
        if (logs.length === 0) {
            logsList.innerHTML = '<p class="text-muted mb-0">无</p>';
            return;
        }
        
        logs.forEach(log => {
            const logItem = document.createElement('div');
            logItem.className = 'border-bottom pb-2 mb-2';
            logItem.innerHTML = `
                <div class="d-flex justify-content-between align-items-start">
                    <div class="flex-grow-1">
                        <h6 class="mb-1">${log.title || '工作日志'}</h6>
                        ${log.content ? `<p class="mb-1 text-muted small">${log.content.length > 100 ? log.content.substring(0, 100) + '...' : log.content}</p>` : ''}
                        <small class="text-muted">
                            <i class="bi bi-clock"></i> ${formatDateTimeDisplay(log.created_at)}
                        </small>
                    </div>
                    <span class="badge bg-${getCategoryBadgeColor(log.category)}">${log.category}</span>
                </div>
            `;
            logsList.appendChild(logItem);
        });
        
        document.getElementById('detailTaskLogsCount').textContent = logs.length;
        document.getElementById('detailTaskLastActivity').textContent = logs.length > 0 ? formatDateTimeDisplay(logs[0].created_at, '无') : '无';
    } catch (error) {
        console.error('加载任务日志失败:', error);
        const logsList = document.getElementById('taskLogsList');
        if (logsList) {
            logsList.innerHTML = '<p class="text-muted mb-0">加载失败</p>';
        }
    }
}

// 打开编辑任务模态框（可从列表或详情进入）
async function editTask(taskId) {
    try {
        const id = taskId || (currentTask && currentTask.id);
        if (!id) {
            showAlert('未选择任务', 'warning');
            return;
        }

        // 确保有用户列表供选择
        if (!users || users.length === 0) {
            await loadUsers();
        }

        // 确保新弹窗在最上层：若在详情里打开，先关闭详情弹窗
        const detailModalInst = bootstrap.Modal.getInstance(document.getElementById('taskDetailModal'));
        if (detailModalInst) {
            detailModalInst.hide();
        }
        resetModalState();

        // 获取任务详情
        const resp = await fetch(`${API_BASE_URL}/tasks/${id}`, { headers: getAuthHeaders() });
        if (!resp.ok) throw new Error('加载任务详情失败');
        const task = await resp.json();
        currentTask = task;

        // 填充编辑表单
        const modalEl = document.getElementById('editTaskModal');
        // 标题/描述
        document.getElementById('editTaskTitle').value = task.title || '';
        document.getElementById('editTaskDescription').value = task.description || '';

        // 优先级映射：后端 p0..p3，对应编辑下拉直接用 p0..p3
        document.getElementById('editTaskPriority').value = task.priority || 'p1';

        // 状态
        document.getElementById('editTaskStatus').value = task.status || 'pending';

        // 责任人下拉
        const assigneeSel = document.getElementById('editTaskAssignee');
        assigneeSel.innerHTML = '<option value="">选择责任人</option>';
        users.forEach(u => {
            const opt = document.createElement('option');
            opt.value = u.id;
            const deptDisp = u.department_name || u.department || '未知部门';
            opt.textContent = `${u.name} (${deptDisp})`;
            assigneeSel.appendChild(opt);
        });
        assigneeSel.value = task.assignee_id || '';
        document.getElementById('editTaskDepartment').value = task.department_name || task.department || '';

        // 时间字段
        const toLocalInput = (dt) => formatDateInputValue(dt);
        document.getElementById('editTaskStartTime').value = toLocalInput(task.start_time);
        document.getElementById('editTaskEndTime').value = toLocalInput(task.end_time);
        document.getElementById('editTaskDeadline').value = toLocalInput(task.deadline);

        // 其他
        document.getElementById('editTaskLocation').value = task.location || '';
        document.getElementById('editTaskIsAllDay').checked = !!task.is_all_day;

        // 显示模态框
        const modal = new bootstrap.Modal(modalEl);
        modal.show();
    } catch (e) {
        console.error(e);
        showAlert(e.message || '打开编辑任务失败', 'danger');
    }
}

// 保存编辑任务
async function updateTask() {
    if (!currentTask) {
        showAlert('未选择任务', 'warning');
        return;
    }

    const form = document.getElementById('editTaskForm');
    if (!form.checkValidity()) {
        form.reportValidity();
        return;
    }

    // 格式化时间
    const fmt = (v) => v ? v.replace('T',' ') + ':00' : null;

    const payload = {
        title: document.getElementById('editTaskTitle').value.trim(),
        description: document.getElementById('editTaskDescription').value.trim(),
        priority: document.getElementById('editTaskPriority').value,
        status: document.getElementById('editTaskStatus').value,
        assignee_id: document.getElementById('editTaskAssignee').value || null,
        start_time: fmt(document.getElementById('editTaskStartTime').value),
        end_time: fmt(document.getElementById('editTaskEndTime').value),
        deadline: fmt(document.getElementById('editTaskDeadline').value),
        location: document.getElementById('editTaskLocation').value || null,
        is_all_day: document.getElementById('editTaskIsAllDay').checked
    };

    // 若状态为已完成或进行中，则同步更新进度
    if (payload.status === 'completed') {
        payload.progress_percentage = 100;
    } else if (payload.status === 'in_progress') {
        payload.progress_percentage = 50;
    }

    try {
        const resp = await fetch(`${API_BASE_URL}/tasks/${currentTask.id}`, {
            method: 'PUT',
            headers: getAuthHeaders(),
            body: JSON.stringify(payload)
        });
        if (!resp.ok) {
            const err = await resp.json().catch(() => ({}));
            throw new Error(err.error || err.message || '更新任务失败');
        }

        showAlert('任务更新成功', 'success');
        const editInst = bootstrap.Modal.getInstance(document.getElementById('editTaskModal'));
        if (editInst) editInst.hide();
        resetModalState();
        // 刷新详情与列表
        await viewTaskDetail(currentTask.id);
        await loadTasks();
    } catch (e) {
        console.error('更新任务失败:', e);
        showAlert(e.message || '更新任务失败', 'danger');
    }
}

// 从详情创建子任务：复用新建任务模态框并注入父任务ID
function createSubtask(parentId) {
    if (!parentId) return;
    showAddTaskModal();
    // 设置标题
    const modalTitle = document.querySelector('#addTaskModal .modal-title');
    if (modalTitle) modalTitle.textContent = '创建子任务';
    // 注入隐藏域保存父任务ID
    let hidden = document.getElementById('parentTaskId');
    if (!hidden) {
        hidden = document.createElement('input');
        hidden.type = 'hidden';
        hidden.id = 'parentTaskId';
        document.getElementById('addTaskForm').appendChild(hidden);
    }
    hidden.value = parentId;
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
                
                // 立即刷新任务列表，确保数据是最新的
                await loadTasks();
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
    
    // 优先从详情页滑杆读取
    const slider = document.getElementById('detailProgressInput');
    const progress = slider ? parseInt(slider.value) : parseInt(prompt('请输入新的进度百分比 (0-100):', currentTask.progress_percentage || 0));
    if (isNaN(progress) || progress < 0 || progress > 100) {
        showAlert('请输入有效的进度值 (0-100)', 'warning');
        return;
    }
    
    // 根据进度自动设置状态：1-99%为进行中，100%为已完成，0%保持原状态
    let status = currentTask.status;
    if (progress >= 1 && progress < 100) {
        status = 'in_progress';
    } else if (progress === 100) {
        status = 'completed';
    }
    
    try {
        const response = await fetch(`${API_BASE_URL}/tasks/${currentTask.id}/status`, {
            method: 'PUT',
            headers: getAuthHeaders(),
            body: JSON.stringify({
                progress_percentage: progress,
                status: status
            })
        });
        
        if (response.ok) {
            showAlert('进度更新成功！', 'success');
            // 刷新任务详情
            await viewTaskDetail(currentTask.id);
            // 更新“最后更新”时间显示
            const nowStr = formatDateTimeDisplay(new Date());
            const last = document.getElementById('lastProgressUpdate');
            if (last) last.textContent = nowStr;
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

// 详情页保存进度按钮
function saveDetailProgress() {
    updateTaskProgress();
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
                resetModalState();
                
                // 清除当前任务
                currentTask = null;
                
                // 立即刷新任务列表，确保数据是最新的
                await loadTasks();
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
    return ROLE_BADGE_COLORS[role] || 'secondary';
}

function getPriorityBadgeColor(priority) {
    switch(priority) {
        case 'p0': return 'danger';
        case 'p1': return 'warning';
        case 'p2': return 'primary';
        case 'p3': return 'secondary';
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
        case 'p0': return '重要且紧急';
        case 'p1': return '重要不紧急';
        case 'p2': return '不重要紧急';
        case 'p3': return '不重要不紧急';
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
    if (typeof task.progress_percentage === 'number') {
        return Math.max(0, Math.min(100, task.progress_percentage));
    }
    // 兼容：若没有明确百分比，根据状态给个大致值
    switch(task.status) {
        case 'completed': return 100;
        case 'in_progress': return 50;
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

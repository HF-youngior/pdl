-- 强制更新所有用户密码为明文
-- 此脚本将覆盖所有现有密码，确保使用明文存储

USE enterprise_management;

-- 更新管理员密码
UPDATE users SET password = 'admin123' WHERE username = 'admin';

-- 更新创始人密码
UPDATE users SET password = 'founder123' WHERE username IN ('founder1', 'founder2');

-- 更新部门总监密码
UPDATE users SET password = 'hr123' WHERE username = 'hr_head';
UPDATE users SET password = 'finance123' WHERE username = 'finance_head';
UPDATE users SET password = 'marketing123' WHERE username = 'marketing_head';

-- 更新团队长密码
UPDATE users SET password = 'hrteam123' WHERE username IN ('hr_team1', 'hr_team2');
UPDATE users SET password = 'financeteam123' WHERE username IN ('finance_team1', 'finance_team2');
UPDATE users SET password = 'marketingteam123' WHERE username IN ('marketing_team1', 'marketing_team2');

-- 更新员工密码
UPDATE users SET password = 'hremp123' WHERE username IN ('hr_emp1', 'hr_emp2', 'hr_emp3', 'hr_emp4');
UPDATE users SET password = 'financeemp123' WHERE username IN ('finance_emp1', 'finance_emp2', 'finance_emp3', 'finance_emp4');
UPDATE users SET password = 'marketingemp123' WHERE username IN ('marketing_emp1', 'marketing_emp2', 'marketing_emp3', 'marketing_emp4');

-- 更新旧版本数据库中的用户密码（如果存在）
UPDATE users SET password = 'admin123' WHERE username = 'admin';
UPDATE users SET password = 'manager123' WHERE username = 'manager';
UPDATE users SET password = 'employee123' WHERE username = 'employee1';

-- 显示更新结果
SELECT 
    username, 
    name, 
    role, 
    password,
    CASE 
        WHEN password LIKE '$2a$%' THEN '❌ 仍然是加密密码'
        WHEN LENGTH(password) < 20 THEN '✅ 明文密码'
        ELSE '⚠️ 未知格式'
    END as password_status
FROM users 
ORDER BY role, username;

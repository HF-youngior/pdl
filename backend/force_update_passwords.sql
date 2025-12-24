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
UPDATE users SET password = 'hrteam123' WHERE username = 'hr_team1';
UPDATE users SET password = 'financeteam123' WHERE username = 'finance_team1';
UPDATE users SET password = 'marketingteam123' WHERE username = 'marketing_team1';

-- 更新员工密码
UPDATE users SET password = 'hremp123' WHERE username = 'hr_emp1';
UPDATE users SET password = 'financeemp123' WHERE username = 'finance_emp1';
UPDATE users SET password = 'marketingemp123' WHERE username = 'marketing_emp1';

-- 更新旧版本数据库中的用户密码（如果存在）
UPDATE users SET password = 'admin123' WHERE username = 'admin';
-- 移除无关账户的重置

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

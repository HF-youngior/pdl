-- 删除2025年12月24日和25日的签到记录
-- 同时恢复相关积分和积分流水

USE enterprise_management;

-- 开始事务
START TRANSACTION;

-- 1. 查找并显示要删除的签到记录
SELECT 
    cr.id as checkin_id,
    cr.user_id,
    u.name as user_name,
    cr.checkin_date,
    cr.points_earned,
    cr.created_at
FROM checkin_records cr
JOIN users u ON cr.user_id = u.id
WHERE cr.checkin_date IN ('2025-12-24', '2025-12-25')
ORDER BY cr.checkin_date, u.name;

-- 2. 恢复用户积分（减去这两天的签到积分）
UPDATE users u
SET points = GREATEST(COALESCE(points, 0) - (
    SELECT COALESCE(SUM(cr.points_earned), 0)
    FROM checkin_records cr
    WHERE cr.user_id = u.id
    AND cr.checkin_date IN ('2025-12-24', '2025-12-25')
), 0)
WHERE EXISTS (
    SELECT 1
    FROM checkin_records cr
    WHERE cr.user_id = u.id
    AND cr.checkin_date IN ('2025-12-24', '2025-12-25')
);

-- 3. 删除相关的积分流水记录（签到获得的积分）
DELETE FROM points_transactions
WHERE type = 'earn'
AND description = '每日签到'
AND related_id IN (
    SELECT id FROM checkin_records
    WHERE checkin_date IN ('2025-12-24', '2025-12-25')
);

-- 4. 删除签到记录
DELETE FROM checkin_records
WHERE checkin_date IN ('2025-12-24', '2025-12-25');

-- 显示删除结果
SELECT 
    '删除完成' as message,
    ROW_COUNT() as deleted_records;

-- 提交事务
COMMIT;

-- 验证删除结果
SELECT 
    '验证：2025-12-24和2025-12-25的签到记录' as check_type,
    COUNT(*) as remaining_records
FROM checkin_records
WHERE checkin_date IN ('2025-12-24', '2025-12-25');


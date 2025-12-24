-- 数据库迁移脚本：为邀约任务添加邀约时间字段
-- 运行此脚本以更新现有的任务表结构

-- 添加邀约时间字段到任务表
ALTER TABLE tasks 
ADD COLUMN IF NOT EXISTS request_start_time TIMESTAMP NULL,
ADD COLUMN IF NOT EXISTS request_end_time TIMESTAMP NULL;

-- 更新现有邀约任务的请求时间字段（如果需要从现有时间字段迁移数据）
-- UPDATE tasks 
-- SET request_start_time = start_time,
--     request_end_time = end_time
-- WHERE is_request = 1;

-- 显示更新后的任务表结构
DESCRIBE tasks;
-- 重构个人日志表与新增日志-任务关联表（MySQL）
-- 注意：执行前请备份旧数据

DROP TABLE IF EXISTS log_task_linkage;
DROP TABLE IF EXISTS personal_logs;

CREATE TABLE personal_logs (
  log_id         VARCHAR(36)  PRIMARY KEY,
  user_id        VARCHAR(36)  NOT NULL,
  log_date       DATE         NOT NULL,
  weather        VARCHAR(50)  NOT NULL,
  keywords       VARCHAR(255) NULL,
  log_title      VARCHAR(200) NOT NULL,
  log_content    TEXT         NULL,
  category       VARCHAR(50)  NOT NULL,
  quadrant       ENUM('important_urgent','important_not_urgent','not_important_urgent','not_important_not_urgent') NOT NULL DEFAULT 'important_not_urgent',
  is_archived    BOOLEAN      NOT NULL DEFAULT FALSE,
  created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP    NULL ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_pl_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE log_task_linkage (
  log_id              VARCHAR(36) NOT NULL,
  task_id             VARCHAR(36) NOT NULL,
  progress_percentage TINYINT     NOT NULL,
  task_status         ENUM('in_progress','completed','interrupted') NOT NULL,
  linkage_time        TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (log_id, task_id),
  CONSTRAINT fk_ltl_log  FOREIGN KEY (log_id)  REFERENCES personal_logs(log_id) ON DELETE CASCADE,
  CONSTRAINT fk_ltl_task FOREIGN KEY (task_id) REFERENCES tasks(id)             ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;



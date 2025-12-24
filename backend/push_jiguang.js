const axios = require('axios');
const APP_KEY = process.env.JPUSH_APP_KEY || 'a7474254450572b4411beacc';
const MASTER_SECRET = process.env.JPUSH_MASTER_SECRET || '7018009694cec1c1c87d36f0';

async function sendPush(registrationId, title, content, extras = {}) {
  const auth = Buffer.from(`${APP_KEY}:${MASTER_SECRET}`).toString('base64');
  const type = extras?.type || '';
  const soundMap = {
    deadline_warning: 'warning.caf',
    task_assigned: 'new_task.caf',
    task_completed: 'completed.caf',
    focus_invite: 'invite.caf'
  };
  const sound = soundMap[type] || 'default';
  const badge = type === 'deadline_warning' ? 2 : 1;
  const payload = {
    platform: 'all',
    audience: { registration_id: [registrationId] },
    notification: {
      android: { alert: content, title, sound, extras, channel_id: 'developer-default' },
      ios: { alert: content, badge, sound, extras }
    },
    options: {
      time_to_live: 86400,
      apns_production: false
    }
  };
  try {
    const res = await axios.post('https://api.jpush.cn/v3/push', payload, {
      headers: { Authorization: `Basic ${auth}`, 'Content-Type': 'application/json' },
      timeout: 15000
    });
    console.log('推送成功:', res.data);
    return true;
  } catch (err) {
    console.error('推送失败:', err.response?.data || err.message);
    return false;
  }
}

if (require.main === module) {
  const testRegId = process.env.TEST_REG_ID || '';
  if (testRegId) {
    sendPush(testRegId, '测试通知', '模拟器收到来自极光的消息', { type: 'test' });
  } else {
    console.log('缺少Registration ID（请设置环境变量 TEST_REG_ID）');
  }
}

module.exports = { sendPush };

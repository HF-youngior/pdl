# DeepSeek API 配置说明

## 环境变量配置

请在 `backend/.env` 文件中添加以下配置：

```env
# DeepSeek API配置
DEEPSEEK_API_KEY=your-deepseek-api-key-here
DEEPSEEK_API_URL=https://api.deepseek.com/v1/chat/completions
```

## 获取API Key

1. 访问 [DeepSeek官网](https://platform.deepseek.com/)
2. 注册账号并登录
3. 在控制台中创建API Key
4. 将API Key复制到上述配置中

## 注意事项

- 请妥善保管您的API Key，不要将其提交到版本控制系统
- 建议定期轮换API Key以提高安全性
- 监控API使用量以避免超出预算

## 免费额度说明

- DeepSeek提供一定的免费额度
- 超出免费额度后按使用量计费
- 建议在开发阶段使用免费额度进行测试

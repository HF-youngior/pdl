# 高德地图API配置指南

## 问题描述
当前配置的API Key (ac23fb340da7b8f3e884b377e9f1d2a7) 是为Android平台创建的，不能用于Web服务API。这会导致错误码10009 (USERKEY_PLAT_NOMATCH)。

## 解决方案

### 1. 获取Web服务API Key
1. 登录[高德开放平台](https://lbs.amap.com/)
2. 进入控制台 → 应用管理 → 我的应用 → 选择您的应用"pdl"
3. 点击"添加" → 选择"Web服务API"
4. 填写信息：
   - 服务名称：可以填写"pdl-web-api"或类似名称
   - 选择服务：Web服务API
5. 提交后，您将获得一个新的API Key，专门用于Web服务API

### 2. 更新配置文件
获取新的Web服务API Key后，更新 `.env` 文件中的 `AMAP_API_KEY` 值：

```
# 高德地图API配置
AMAP_API_KEY=您的Web服务API_Key
```

### 3. 重启服务器
更新配置后，重启后端服务器以使新配置生效。

## 临时解决方案
在获取正确的Web服务API Key之前，系统已经配置了备用方案：
- 当API Key平台不匹配时，系统将返回原始经纬度信息
- 日志中会显示警告信息，提醒您配置正确的API Key
- 前端仍可正常显示坐标信息，只是不会转换为地址

## 测试API Key
获取新的API Key后，可以使用以下命令测试：

```bash
cd backend
node test_amap_api.js
```

## 注意事项
- Android平台的API Key和Web服务API Key是不同的，不能混用
- Web服务API Key有每日调用次数限制，请合理使用
- 建议在生产环境中使用HTTPS协议调用API
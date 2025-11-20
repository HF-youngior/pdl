## 局域网文件服务搭建指南

本项目的图片上传能力已经内置于 `backend/server_enterprise.js`。按照以下步骤配置后，就能在同一局域网内让电脑、手机等多端共享访问图片 URL。

1. **启动后端并开放 8080 端口**
   - 在 `backend` 目录执行 `npm install`（首次）和 `npm run start-enterprise`（或运行 `start_enterprise_backend_correct.bat`）。
   - Windows 防火墙提示时选择“允许访问”；否则在 `allow_port_8080.bat` 中自动放行。

2. **确认电脑 IP**
   - Windows：`Win + R` → 输入 `cmd` → `ipconfig`，找到当前 Wi-Fi 的 `IPv4 地址`，形如 `192.168.1.123`。
   - Mac/Linux：终端执行 `ifconfig` 或 `ip addr`，找到 `inet 192.168.x.x`。

3. **配置客户端的服务器地址**
   - 打开 App → 设置 → 服务器配置。
   - Host 填写上一步的 IP，Port 保持 `8080`。
   - 保存后重启 App。也可以在开发环境里调用 `ServerConfigService.setServerHost('<IP>')`。

4. **图片上传与访问**
   - 日志、任务等页面在点击“保存”时会先调用 `/api/upload-images`，后端把文件写入 `backend/public/uploads/YYYY-MM-DD/xxx.jpg`。
   - 接口返回 `http://<IP>:8080/uploads/xxx.jpg`，这些 URL 会存入数据库，任何在同一网络的设备都能访问。

5. **多端验证**
   - 使用电脑浏览器打开 `http://<IP>:8080/uploads/`，应能列出刚刚上传的图片。
   - 在另一台手机/平板上设置同一个服务器地址后，打开日志或任务详情，图片即会显示为公网 URL，而不是本地 `file://` 路径。

> 若需公网访问，把同一套 Node 服务部署到云主机或通过内网穿透工具（frp、ZeroTier 等）暴露端口即可，前端无需改动。



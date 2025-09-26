# Android Studio 运行说明

## 项目配置

### 1. 打开项目
1. 启动 Android Studio
2. 选择 "Open an existing Android Studio project"
3. 选择 `F:\TestFlutterProject\android` 文件夹
4. 等待项目同步完成

### 2. 项目结构
```
android/
├── app/
│   ├── build.gradle.kts          # 应用配置
│   └── src/main/
│       ├── AndroidManifest.xml   # 应用清单
│       └── kotlin/               # Kotlin代码
├── build.gradle.kts              # 项目配置
└── settings.gradle.kts           # 设置文件
```

### 3. 应用配置
- **应用名称**: 企业管理系统
- **包名**: com.enterprise.management
- **最低SDK**: 21 (Android 5.0)
- **目标SDK**: 34 (Android 14)

### 4. 权限配置
应用已配置以下权限：
- `INTERNET` - 网络访问权限
- `ACCESS_NETWORK_STATE` - 网络状态访问权限

## 运行步骤

### 1. 启动后端服务器
在运行Android应用之前，需要先启动后端服务器：

```bash
# 方法1: 使用批处理文件
双击运行 start_backend.bat

# 方法2: 手动启动
cd backend
npm install
npm start
```

确保看到以下输出：
```
数据库连接成功
服务器运行在端口 3000
API地址: http://localhost:3000/api
```

### 2. 在Android Studio中运行
1. 在Android Studio中打开项目
2. 连接Android设备或启动模拟器
3. 点击 "Run" 按钮 (绿色三角形) 或按 Shift+F10
4. 选择目标设备
5. 等待应用安装和启动

### 3. 测试应用
1. 应用启动后会显示登录页面
2. 使用以下测试账户登录：
   - 管理员: admin / admin123
   - 部门老总: manager / manager123
   - 普通员工: employee1 / employee123

## 网络配置说明

### Android模拟器网络配置
- 应用使用 `http://10.0.2.2:3000/api` 作为API地址
- `10.0.2.2` 是Android模拟器访问主机localhost的特殊地址
- 确保后端服务器在主机上运行在3000端口

### 真机调试网络配置
如果使用真机调试，需要修改API地址：
1. 确保手机和电脑在同一WiFi网络
2. 获取电脑的IP地址 (如: 192.168.1.100)
3. 修改 `lib/services/api_service.dart` 中的baseUrl：
   ```dart
   static const String baseUrl = 'http://192.168.1.100:3000/api';
   ```

## 常见问题

### 1. 网络连接失败
- 检查后端服务器是否正在运行
- 检查防火墙设置
- 确认API地址是否正确

### 2. 应用崩溃
- 检查Android Studio的Logcat输出
- 确认所有依赖都已正确安装
- 检查设备或模拟器的Android版本是否支持

### 3. 数据库连接问题
- 确保MySQL服务正在运行
- 检查.env文件中的数据库配置
- 确认数据库已正确初始化

## 开发建议

1. **使用模拟器**: 推荐使用Android Studio自带的模拟器进行开发
2. **网络调试**: 使用Chrome开发者工具监控网络请求
3. **日志查看**: 使用Android Studio的Logcat查看应用日志
4. **热重载**: 修改Flutter代码后可以使用热重载快速测试

## 下一步开发

1. 在Android Studio中修改Flutter代码
2. 使用热重载功能快速测试
3. 根据需要添加新的Android特定功能
4. 配置应用签名用于发布

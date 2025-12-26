# Android Studio 运行说明

## 项目配置

### 1. 打开项目（推荐方式）
**重要**: 对于 Flutter 项目，应该打开项目根目录，而不是 android 文件夹！

1. 启动 Android Studio
2. 选择 **"Open"** 或 **"Open or Import"**
3. 选择项目根目录（包含 `pubspec.yaml` 和 `android` 文件夹的目录，如 `D:\pdl`）
4. 等待 Android Studio 识别为 Flutter 项目并完成同步

### 1.1 如果已经打开了 android 文件夹
如果已经打开了 `android` 文件夹导致配置问题，请：
1. **File → Close Project**
2. 重新打开项目根目录（包含 `pubspec.yaml` 的目录）
3. 等待同步完成

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

#### 方法1: 使用 Flutter 运行配置（推荐）
1. 在顶部工具栏选择设备（手机/模拟器）
2. 点击 **"Flutter"** 运行配置（或选择 `main.dart` 然后运行）
3. 点击 "Run" 按钮或按 `Shift+F10`
4. 等待应用安装和启动

#### 方法2: 使用 Android App 配置
如果必须使用 Android App 配置，需要修复 "Module not specified" 错误：

1. **File → Project Structure** (或按 `Ctrl+Alt+Shift+S`)
2. 在左侧选择 **"Modules"**
3. 确保 `app` 模块存在且已正确配置
4. 如果没有 `app` 模块：
   - 点击 **"+"** 添加模块
   - 选择 **"Import Gradle Project"**
   - 选择 `android/app` 目录
5. 在运行配置中：
   - **Run → Edit Configurations**
   - 选择 "app" 配置
   - 在 **Module** 下拉菜单中选择 **":app"** 或 **"app"**
   - 点击 **OK** 保存

#### 修复 Module 问题的快速方法
如果运行配置中显示 "Module not specified"：
1. 点击 **"Run → Edit Configurations"**
2. 选择 "app" 配置
3. 在 **Module** 字段中，如果显示 `<no module>`：
   - 点击下拉菜单
   - 选择 **"app"** 或 **":app"**
   - 如果列表为空，需要先同步项目：
     - **File → Sync Project with Gradle Files** (或工具栏的同步图标)
4. 点击 **OK** 保存

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

### 0. Module not specified 错误
**症状**: 运行配置显示 "Error: Module not specified"

**解决方法**:
1. **同步 Gradle 项目**:
   - 点击工具栏的 "Sync Project with Gradle Files" 图标（🔄）
   - 或 **File → Sync Project with Gradle Files**
   - 等待同步完成

2. **检查项目结构**:
   - **File → Project Structure** → **Modules**
   - 确保 "app" 模块存在

3. **修复运行配置**:
   - **Run → Edit Configurations**
   - 选择 "app" 配置
   - 在 **Module** 下拉菜单选择 **":app"**
   - 如果列表为空，先执行步骤1同步项目

4. **重新导入项目**（最后手段）:
   - **File → Invalidate Caches → Invalidate and Restart**
   - 或者在项目根目录运行: `flutter pub get` 和 `cd android && ./gradlew clean`

5. **使用 Flutter 配置代替**:
   - 如果以上方法都不行，直接在 `lib/main.dart` 文件上右键
   - 选择 **"Run 'main.dart'"**
   - 这会使用 Flutter 运行配置，不依赖 Android 模块配置

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

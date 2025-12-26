# 修复 Android Studio "Module not specified" 错误

## 问题描述
在 Android Studio 中运行 Flutter 项目时，运行配置显示 "Error: Module not specified"，Module 下拉菜单显示 `<no module>`。

## 快速解决方法（按优先级）

### 方法1: 同步 Gradle 项目（最简单）
1. 在 Android Studio 顶部工具栏，找到 **"Sync Project with Gradle Files"** 按钮（🔄图标）
2. 点击同步，等待完成
3. 重新打开 **Run → Edit Configurations**
4. 在 Module 下拉菜单中选择 **":app"** 或 **"app"**
5. 点击 **OK**

### 方法2: 使用 Flutter 运行配置（推荐）
不依赖 Android App 配置，直接使用 Flutter 配置：
1. 在项目树中找到 `lib/main.dart`
2. 右键点击 `main.dart`
3. 选择 **"Run 'main.dart'"**
4. 或者点击顶部工具栏的运行配置下拉菜单，选择 **"main.dart"**

### 方法3: 修复运行配置
1. **Run → Edit Configurations...**
2. 选择左侧的 **"app"** 配置
3. 在右侧 **"General"** 标签页中：
   - 找到 **"Module"** 字段
   - 点击下拉菜单（可能显示为 `<no module>`）
   - 选择 **":app"** 
   - 如果没有选项，先执行**方法1**同步项目
4. 点击 **OK** 保存

### 方法4: 检查项目结构
1. **File → Project Structure** (快捷键: `Ctrl+Alt+Shift+S`)
2. 左侧选择 **"Modules"**
3. 检查是否有 **"app"** 模块
4. 如果没有：
   - 点击 **"+"** 添加
   - 选择 **"Import Gradle Project"**
   - 浏览到 `android/app` 目录并选择
5. 应用更改，重新同步项目

### 方法5: 重新打开项目（如果以上都不行）
如果项目打开方式不正确：
1. **File → Close Project**
2. 重新打开项目：
   - **Open** → 选择**项目根目录**（包含 `pubspec.yaml` 的目录，如 `D:\pdl`）
   - **不要**只打开 `android` 文件夹
3. 等待 Android Studio 识别为 Flutter 项目
4. 等待 Gradle 同步完成

### 方法6: 清理并重新构建
在项目根目录执行：
```bash
flutter clean
cd android
gradlew clean
cd ..
flutter pub get
```
然后在 Android Studio 中：
1. **File → Invalidate Caches → Invalidate and Restart**
2. 等待重启后重新同步项目

## 预防措施
1. **始终打开项目根目录**，不要只打开 `android` 文件夹
2. **确保已安装 Flutter 插件**
   - File → Settings → Plugins
   - 搜索 "Flutter" 确保已安装
3. **使用 Flutter 运行配置**而不是 Android App 配置

## 验证修复
修复后，运行配置应该：
- Module 字段显示 **":app"** 或 **"app"**
- 没有红色错误提示
- 可以正常选择运行/调试

## 仍然无法解决？
如果以上方法都不行，检查：
1. 是否安装了 Flutter SDK
2. 是否在 `android/local.properties` 中正确配置了 Flutter SDK 路径
3. 项目是否被正确识别为 Flutter 项目（查看项目树是否有 Flutter 相关图标）


# Gradle构建加速指南

## 🚀 已应用的优化

我已经优化了`android/gradle.properties`文件，添加了以下配置：

### 1. 并行构建
```properties
org.gradle.parallel=true
```
- 允许Gradle同时构建多个模块，充分利用多核CPU

### 2. 构建缓存
```properties
org.gradle.caching=true
```
- 缓存构建输出，相同输入时直接使用缓存

### 3. Gradle守护进程
```properties
org.gradle.daemon=true
```
- 保持Gradle进程运行，避免每次启动的开销

### 4. JVM内存优化
```properties
org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m
```
- 分配8GB内存给Gradle，避免频繁GC

### 5. 网络超时优化
```properties
systemProp.http.socketTimeout=60000
systemProp.http.connectionTimeout=60000
```
- 避免网络请求无限等待

## ⚡ 立即加速的方法

### 方法1: 使用优化脚本（推荐）

运行优化脚本清理缓存并重新初始化：

```batch
cd android
优化Gradle构建.bat
```

这个脚本会：
1. 停止旧的Gradle守护进程
2. 清理所有构建缓存
3. 重新获取依赖
4. 预下载Gradle依赖

### 方法2: 手动清理和重建

如果构建卡住了，可以尝试：

```batch
# 1. 停止Gradle守护进程
cd android
gradlew.bat --stop

# 2. 清理Flutter缓存
cd ..
flutter clean

# 3. 清理Gradle缓存
cd android
gradlew.bat clean

# 4. 重新获取依赖
cd ..
flutter pub get

# 5. 在Android Studio中点击 Sync Project with Gradle Files
```

### 方法3: 跳过构建直接运行

如果只是想要运行应用，可以：

1. **使用Windows版本**（最快）：
   ```batch
   flutter run -d windows
   ```

2. **使用Web版本**：
   ```batch
   flutter run -d chrome
   ```

3. **如果必须在Android运行**，在Android Studio中：
   - 点击 `Run` → `Edit Configurations`
   - 在 `Before launch` 中取消勾选 `Gradle-aware Make`
   - 直接运行（但这可能导致某些功能不可用）

## 🔍 诊断构建慢的问题

### 检查网络连接

如果构建一直卡在下载依赖，可能是网络问题：

```batch
# 测试连接到阿里云Maven镜像
ping maven.aliyun.com
```

### 检查Gradle守护进程状态

```batch
cd android
gradlew.bat --status
```

如果看到多个守护进程，可以停止它们：

```batch
gradlew.bat --stop
```

### 查看详细构建日志

在Android Studio中：
1. 打开 `View` → `Tool Windows` → `Build`
2. 查看具体卡在哪一步

或者在命令行：

```batch
cd android
gradlew.bat build --info
```

## 📊 构建时间对比

- **首次构建（无缓存）**: 10-20分钟
- **首次构建（有缓存）**: 5-10分钟
- **增量构建**: 1-3分钟
- **使用守护进程后**: 再减少30-50%

## 🎯 最佳实践

1. **首次构建后保留守护进程**
   - 不要关闭终端，让守护进程保持运行
   - 后续构建会快很多

2. **定期清理**
   - 每周运行一次 `优化Gradle构建.bat`
   - 保持缓存合理大小

3. **使用本地Maven镜像**
   - 已配置阿里云镜像，应该下载更快

4. **避免同时运行多个构建**
   - 关闭其他IDE项目
   - 关闭不必要的程序释放内存

## 🐛 常见问题

### Q: 构建一直卡在 "Downloading" 或 "Download https://..."

**解决方案**:
1. 检查网络连接
2. 查看是否有防火墙阻止
3. 尝试使用VPN或更换网络
4. 手动下载到本地仓库（高级用户）

### Q: 内存不足错误 (OutOfMemoryError)

**解决方案**:
1. 关闭其他程序
2. 减少JVM内存设置（在gradle.properties中修改 `-Xmx8G` 为 `-Xmx4G`）
3. 重启计算机

### Q: 构建成功后还是运行失败

**解决方案**:
```batch
# 清理后重新构建
flutter clean
flutter pub get
flutter run
```

## 💡 额外提示

- **首次同步/构建总是最慢的**，因为需要下载所有依赖
- **第二次构建会快很多**，因为使用了缓存
- **使用SSD硬盘会显著加快构建速度**
- **关闭杀毒软件的实时扫描**（特别是对项目文件夹）

## 📞 如果还是慢

如果优化后构建仍然很慢，请检查：

1. 系统资源使用情况（CPU、内存、磁盘）
2. 网络连接速度
3. 是否有其他进程占用资源
4. 硬盘空间是否充足（至少需要10GB空闲空间）


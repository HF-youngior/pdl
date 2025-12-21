# SonarQube Java 21 兼容性问题解决方案

## 问题诊断

通过分析日志发现，SonarQube 9.9.0 启动失败的根本原因是：

```
Exception in thread "main" java.lang.UnsupportedOperationException: 
The Security Manager is deprecated and will be removed in a future release
```

这是因为 SonarQube 9.9.0 内置的 Elasticsearch 与 Java 21 不兼容。

## 解决方案

### 方案1：安装 Java 17（推荐）

**步骤：**
1. 下载 Java 17 LTS 版本：https://adoptium.net/temurin/releases/?version=17
2. 安装 Java 17 到默认路径
3. 设置环境变量：
   - `JAVA_HOME = C:\Program Files\Eclipse Adoptium\jdk-17.0.x.x-hotspot\`
   - 在 `PATH` 中添加 `%JAVA_HOME%\bin`
4. 重新启动 SonarQube

**验证命令：**
```bash
java -version
# 应该显示 Java 17 版本信息
```

### 方案2：下载新版 SonarQube

**步骤：**
1. 访问 SonarQube 官网：https://www.sonarsource.com/downloads/
2. 下载 SonarQube 10.x 版本（支持 Java 21）
3. 解压到新的目录
4. 重新配置项目

### 方案3：临时修复当前版本（仅用于测试）

**手动修改步骤：**
1. 打开文件：`D:\sonarqube-9.9.0.65466\elasticsearch\config\jvm.options`
2. 在文件末尾添加以下行：
   ```
   -Djava.security.manager=allow
   ```
3. 保存文件
4. 重新启动 SonarQube

**注意：** 这个方案可能影响安全性，仅建议在测试环境中使用。

## 推荐操作流程

1. **首选方案1**：安装 Java 17，这是最稳定和官方推荐的解决方案
2. 如果需要使用最新特性，**选择方案2**：升级到 SonarQube 10.x
3. 仅在临时测试情况下，**考虑方案3**

## 验证 SonarQube 启动成功

启动后检查以下指标：
- 访问 http://localhost:9000 能正常打开
- 查看 `D:\sonarqube-9.9.0.65466\logs\sonar.log` 无错误信息
- 运行 `netstat -an | findstr :9000` 显示端口监听

## 后续步骤

SonarQube 启动成功后：
1. 运行安全扫描：`f:\pdl\run_sonarqube_scan.bat`
2. 访问 Web 界面查看扫描结果
3. 根据扫描报告修复发现的安全问题

## 相关文件

- SonarQube 配置：`f:\pdl\sonar-project.properties`
- 扫描脚本：`f:\pdl\run_sonarqube_scan.bat`
- 安全预检查：`f:\pdl\security_precheck.js`
- 安全报告模板：`f:\pdl\静态安全测试报告.md`
@echo off
chcp 65001 >nul
echo ====================================
echo PDL企业管理系统 - 完整覆盖率扫描
echo ====================================
echo.
echo 步骤1: 生成完整覆盖率报告...
node f:\pdl\generate_full_coverage.js
echo.
echo 步骤2: 运行SonarQube扫描...
& "D:\sonar-scanner-4.8.0.2856\bin\sonar-scanner.bat" "-D sonar.login=sqp_5d7884ce3957f7c0f5449d1a8d5a9bd1ec355d49"
echo.
echo ====================================
echo 扫描完成！请访问以下地址查看结果:
echo http://localhost:9000/dashboard?id=pdl_enterprise_backend
echo ====================================
pause
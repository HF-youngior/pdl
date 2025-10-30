@echo off
echo ========================================
echo AI性格分析功能测试脚本
echo ========================================
echo.
echo 测试admin和hr_head账号的AI性格分析功能
echo.

REM 设置API基础URL
set API_URL=http://localhost:8080/api

echo 1. 测试admin账号登录...
curl -X POST %API_URL%/auth/login ^
  -H "Content-Type: application/json" ^
  -d "{\"username\":\"admin\",\"password\":\"admin123\"}" ^
  -o admin_login.json

echo.
echo 2. 测试hr_head账号登录...
curl -X POST %API_URL%/auth/login ^
  -H "Content-Type: application/json" ^
  -d "{\"username\":\"hr_head\",\"password\":\"hr123\"}" ^
  -o hr_login.json

echo.
echo 3. 获取admin的MBTI记录...
curl -X GET "%API_URL%/mbti-records?limit=1" ^
  -H "Content-Type: application/json" ^
  -H "Authorization: Bearer $(Get-Content admin_login.json | ConvertFrom-Json | Select-Object -ExpandProperty token)" ^
  -o admin_mbti.json

echo.
echo 4. 获取hr_head的MBTI记录...
curl -X GET "%API_URL%/mbti-records?limit=1" ^
  -H "Content-Type: application/json" ^
  -H "Authorization: Bearer $(Get-Content hr_login.json | ConvertFrom-Json | Select-Object -ExpandProperty token)" ^
  -o hr_mbti.json

echo.
echo 5. 测试admin的AI性格分析...
curl -X POST %API_URL%/ai/personality-analysis ^
  -H "Content-Type: application/json" ^
  -H "Authorization: Bearer $(Get-Content admin_login.json | ConvertFrom-Json | Select-Object -ExpandProperty token)" ^
  -d "{\"logText\":\"今天完成了系统维护工作，处理了一些技术问题，感觉很有成就感。\",\"mbtiType\":\"INFP\",\"useDeepSeek\":false}" ^
  -o admin_analysis.json

echo.
echo 6. 测试hr_head的AI性格分析...
curl -X POST %API_URL%/ai/personality-analysis ^
  -H "Content-Type: application/json" ^
  -H "Authorization: Bearer $(Get-Content hr_login.json | ConvertFrom-Json | Select-Object -ExpandProperty token)" ^
  -d "{\"logText\":\"今天组织了部门会议，制定了新的招聘计划，确保团队高效运转。\",\"mbtiType\":\"ESTJ\",\"useDeepSeek\":false}" ^
  -o hr_analysis.json

echo.
echo ========================================
echo 测试完成！
echo ========================================
echo.
echo 查看结果文件:
echo - admin_login.json: admin登录结果
echo - hr_login.json: hr_head登录结果
echo - admin_mbti.json: admin的MBTI记录
echo - hr_mbti.json: hr_head的MBTI记录
echo - admin_analysis.json: admin的AI分析结果
echo - hr_analysis.json: hr_head的AI分析结果
echo.
pause

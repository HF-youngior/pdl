@echo off
chcp 65001 >nul
echo 测试后端API连接...
echo.

echo 测试登录API...
powershell -Command "try { $response = Invoke-WebRequest -Uri 'http://localhost:8080/api/auth/login' -Method POST -ContentType 'application/json' -Body '{\"username\":\"admin\",\"password\":\"admin123\"}' -UseBasicParsing; Write-Host '✅ 登录API正常，状态码:' $response.StatusCode } catch { Write-Host '❌ 登录API失败:' $_.Exception.Message }"

echo.
echo 测试部门API...
powershell -Command "try { $response = Invoke-WebRequest -Uri 'http://localhost:8080/api/departments' -UseBasicParsing; Write-Host '✅ 部门API正常，状态码:' $response.StatusCode } catch { Write-Host '❌ 部门API失败:' $_.Exception.Message }"

echo.
echo 测试完成！
pause

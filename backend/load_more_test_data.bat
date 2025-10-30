@echo off
chcp 65001 > nul
echo ========================================
echo 导入更多测试数据到数据库
echo ========================================
echo.
echo 这将为以下用户增加更多数据：
echo   - hr_head: 9月新增5条日志+4个任务
echo   - hr_head: 10月新增6条日志+5个任务  
echo   - hr_head: 11月新增7条日志+5个任务
echo   - 以及其他用户的补充数据
echo.
echo 正在导入数据...
echo.

mysql -h localhost -u root -pasdfgh0625YYH enterprise_management < add_more_test_data.sql

if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo ✅ 数据导入成功！
    echo ========================================
    echo.
    echo 现在可以在月视图中看到更丰富的数据了！
    echo.
    echo 按任意键关闭窗口...
    pause > nul
) else (
    echo.
    echo ========================================
    echo ❌ 数据导入失败！
    echo ========================================
    echo.
    echo 请检查：
    echo 1. MySQL服务是否启动
    echo 2. 数据库连接信息是否正确
    echo 3. SQL文件是否存在
    echo.
    echo 按任意键关闭窗口...
    pause > nul
)

























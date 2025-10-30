# PowerShell 脚本：加载 HR 总监测试数据

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "加载 HR 总监测试数据" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "正在为 hr_head 用户添加 2025年10月份的数据..." -ForegroundColor Yellow
Write-Host ""

# 使用 UTF-8 编码读取 SQL 文件
$sqlContent = Get-Content -Path "migrations\2025-10-hr-head-data-compatible.sql" -Encoding UTF8 -Raw

# 通过临时文件执行
$tempFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($tempFile, $sqlContent, [System.Text.Encoding]::UTF8)

# 执行 SQL
& mysql -u root -pPyx_07091817 enterprise_management "--default-character-set=utf8mb4" -e "source $tempFile"

# 删除临时文件
Remove-Item $tempFile

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✓ 数据加载成功！" -ForegroundColor Green
    Write-Host ""
    Write-Host "已为 hr_head 用户创建：" -ForegroundColor Green
    Write-Host "  - 10个任务（涵盖招聘、培训、绩效、员工关系等）" -ForegroundColor White
    Write-Host "  - 18条个人日志（2025年10月1-18日）" -ForegroundColor White
    Write-Host "  - 日志与任务的关联关系" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "✗ 数据加载失败，请检查错误信息" -ForegroundColor Red
    Write-Host ""
}

Write-Host "按任意键继续..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")


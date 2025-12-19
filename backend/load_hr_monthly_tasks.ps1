# ========================================
# 为 hr_head 添加月度任务数据 (PowerShell 版本)
# ========================================

Write-Host "========================================"
Write-Host "为 hr_head 添加月度任务数据"
Write-Host "========================================"
Write-Host ""

# 设置数据库连接参数
$DB_HOST = "rm-2ze22f1xm8vvw4m44to.mysql.rds.aliyuncs.com"
$DB_PORT = "3306"
$DB_USER = "pdl"
$DB_PASS = "Pdl1234567"
$DB_NAME = "enterprise_management"

Write-Host "正在读取 SQL 脚本..."

# 读取 SQL 文件并转换为 UTF-8
$sqlContent = Get-Content -Path "add_hr_head_monthly_tasks.sql" -Raw -Encoding UTF8

# 创建临时文件
$tempFile = [System.IO.Path]::GetTempFileName()
$tempFile = $tempFile -replace '\.tmp$', '.sql'

# 以 UTF-8 无 BOM 格式写入临时文件
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($tempFile, $sqlContent, $utf8NoBom)

Write-Host "正在执行 SQL 脚本..."
Write-Host ""

# 执行 SQL
$process = Start-Process -FilePath "mysql" `
    -ArgumentList "-h$DB_HOST","-P$DB_PORT","-u$DB_USER","-p$DB_PASS",$DB_NAME,"--default-character-set=utf8mb4","-e","source $tempFile" `
    -Wait -NoNewWindow -PassThru

# 删除临时文件
Remove-Item $tempFile -ErrorAction SilentlyContinue

if ($process.ExitCode -eq 0) {
    Write-Host ""
    Write-Host "========================================"
    Write-Host "✅ 月度任务数据添加成功！"
    Write-Host "========================================"
    Write-Host ""
    Write-Host "已添加数据："
    Write-Host "- 2025年9月：20条任务"
    Write-Host "- 2025年10月：20条任务"
    Write-Host "- 2025年11月：20条任务"
    Write-Host "- 2025年12月：20条任务"
    Write-Host ""
    Write-Host "状态分布："
    Write-Host "- 待处理：约50%"
    Write-Host "- 进行中：约20%"
    Write-Host "- 已完成：约30%"
    Write-Host ""
    Write-Host "时间跨度：2-4天"
    Write-Host "========================================"
} else {
    Write-Host ""
    Write-Host "========================================"
    Write-Host "❌ 数据添加失败，请检查错误信息"
    Write-Host "退出代码: $($process.ExitCode)"
    Write-Host "========================================"
}

Write-Host ""
Read-Host "按 Enter 键退出"



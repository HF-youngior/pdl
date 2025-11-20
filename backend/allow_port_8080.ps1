# 允许 8080 端口通过 Windows 防火墙
# 用于 Flutter 后端服务器

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "配置 Windows 防火墙允许 8080 端口" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查是否已存在规则
$existingRule = Get-NetFirewallRule -DisplayName "Flutter Backend Server Port 8080" -ErrorAction SilentlyContinue

if ($existingRule) {
    Write-Host "⚠️  已存在防火墙规则，正在删除旧规则..." -ForegroundColor Yellow
    Remove-NetFirewallRule -DisplayName "Flutter Backend Server Port 8080" -ErrorAction SilentlyContinue
}

# 添加入站规则
Write-Host "正在添加防火墙规则..." -ForegroundColor White

$result = New-NetFirewallRule -DisplayName "Flutter Backend Server Port 8080" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow -Profile Any -Description "允许 Flutter 后端服务器端口 8080，用于手机连接" -ErrorAction SilentlyContinue

if ($result) {
    Write-Host ""
    Write-Host "✅ 防火墙规则添加成功！" -ForegroundColor Green
    Write-Host ""
    Write-Host "现在手机可以通过以下地址访问服务器：" -ForegroundColor White
    Write-Host "   http://10.61.194.8:8080/api" -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "❌ 添加防火墙规则失败！" -ForegroundColor Red
    Write-Host ""
    Write-Host "请确保以管理员身份运行此脚本！" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "配置完成" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "按任意键退出..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

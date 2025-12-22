import os
import subprocess
import webbrowser
from pathlib import Path
import shutil

# 设置路径
jmeter_path = Path(__file__).parent / 'jmeter' / 'apache-jmeter-5.4.3' / 'bin' / 'jmeter.bat'
test_script = Path(__file__).parent / 'jmeter_performance_test.jmx'
results_file = Path(__file__).parent / 'test_results.jtl'
report_dir = Path(__file__).parent / 'html_report'

# 检查Java环境
print("检查Java环境...")
try:
    result = subprocess.run(['java', '-version'], check=True, capture_output=True, text=True)
    print("检测到Java环境:")
    print(result.stderr)
except subprocess.CalledProcessError:
    print("错误: 未检测到Java环境，请先安装Java")
    print("下载地址: https://www.java.com/download/")
    exit(1)

# 检查JMeter是否存在
if not jmeter_path.exists():
    print("错误: 未找到JMeter")
    print("请按照以下步骤操作:")
    print("1. 访问 https://jmeter.apache.org/download_jmeter.cgi")
    print("2. 下载最新版本的JMeter ZIP文件")
    print("3. 将ZIP文件解载到", Path(__file__).parent / 'jmeter', "目录")
    print("   解压后应存在:", jmeter_path)
    exit(1)

# 检查PDL服务器是否运行
print("检查PDL服务器...")
try:
    result = subprocess.run(['curl', '-s', 'http://127.0.0.1:8080/api/health'], 
                          check=True, capture_output=True, text=True)
    print("PDL服务器运行正常")
except subprocess.CalledProcessError:
    print("警告: 无法连接到PDL服务器 (http://127.0.0.1:8080)")
    print("请确保PDL服务器正在运行，在另一个终端中执行:")
    print("cd", Path(__file__).parent)
    print("node server_enterprise.js")
    print("")

# 清理旧结果
print("清理旧的测试结果...")
if results_file.exists():
    results_file.unlink()
if report_dir.exists():
    shutil.rmtree(report_dir)

# 运行JMeter测试
print("开始执行JMeter性能测试...")
print("测试脚本:", test_script)
print("结果文件:", results_file)
print("")

result = subprocess.run([str(jmeter_path), '-n', '-t', str(test_script), '-l', str(results_file)])
if result.returncode != 0:
    print("JMeter测试执行失败")
    exit(1)

print("JMeter测试执行完成")

# 检查测试结果文件是否存在
if not results_file.exists():
    print("错误: 测试结果文件未生成")
    exit(1)

# 生成HTML报表
print("生成HTML可视化报表...")
print("报表目录:", report_dir)
print("")

result = subprocess.run([str(jmeter_path), '-g', str(results_file), '-o', str(report_dir)])
if result.returncode != 0:
    print("HTML报表生成失败")
    exit(1)

# 检查HTML报表是否生成成功
if not (report_dir / 'index.html').exists():
    print("错误: HTML报表文件未生成")
    exit(1)

# 打开报表
print("测试完成，正在打开报表...")
webbrowser.open(f'file://{report_dir / "index.html"}')

print("")
print("========================================")
print("测试完成!")
print("========================================")
print("")
print("测试结果文件:", results_file)
print("HTML报表目录:", report_dir)
print("")
print("如需重新运行测试，请再次执行此脚本")
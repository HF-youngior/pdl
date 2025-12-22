import os
import subprocess
import webbrowser
from pathlib import Path
import shutil

# 设置路径
jmeter_path = Path(__file__).parent / 'jmeter' / 'apache-jmeter-5.4.3' / 'bin' / 'jmeter.bat'
results_file = Path(__file__).parent / 'test_results.jtl'
report_dir = Path(__file__).parent / 'html_report'

# 检查结果文件是否存在
if not results_file.exists():
    print("错误: 测试结果文件不存在:", results_file)
    exit(1)

print("找到测试结果文件:", results_file)

# 检查JMeter是否存在
if not jmeter_path.exists():
    print("错误: 未找到JMeter")
    print("请按照以下步骤操作:")
    print("1. 访问 https://jmeter.apache.org/download_jmeter.cgi")
    print("2. 下载最新版本的JMeter ZIP文件")
    print("3. 将ZIP文件解载到", Path(__file__).parent / 'jmeter', "目录")
    print("   解压后应存在:", jmeter_path)
    exit(1)

# 清理旧报表
print("清理旧的报表...")
if report_dir.exists():
    shutil.rmtree(report_dir)

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
print("报表生成完成，正在打开报表...")
webbrowser.open(f'file://{report_dir / "index.html"}')

print("")
print("========================================")
print("报表生成完成!")
print("========================================")
print("")
print("测试结果文件:", results_file)
print("HTML报表目录:", report_dir)
print("")
print("报表已在浏览器中打开")
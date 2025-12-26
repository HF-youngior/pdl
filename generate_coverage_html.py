#!/usr/bin/env python3
"""
简单的覆盖率HTML报告生成器
用于生成代码覆盖率可视化报告
"""
import os
import re

def parse_lcov(lcov_file):
    """解析lcov.info文件"""
    files = {}
    current_file = None
    
    try:
        with open(lcov_file, 'r', encoding='utf-8') as f:
            for line in f:
                if line.startswith('SF:'):
                    current_file = line[3:].strip()
                    files[current_file] = {'lines': [], 'total': 0, 'covered': 0}
                elif line.startswith('DA:') and current_file:
                    parts = line[3:].strip().split(',')
                    if len(parts) == 2:
                        try:
                            line_num = int(parts[0])
                            count = int(parts[1])
                            files[current_file]['lines'].append((line_num, count))
                            files[current_file]['total'] += 1
                            if count > 0:
                                files[current_file]['covered'] += 1
                        except ValueError:
                            continue
    except Exception as e:
        print(f"解析文件时出错: {e}")
        return {}
    
    return files

def generate_html(files, output_file):
    """生成HTML报告"""
    # 只显示核心测试文件
    core_files = [
        'lib/models/log.dart',
        'lib/services/log_service.dart',
        'lib/models/wordcloud_analysis.dart',
        'lib/models/personality_analysis.dart',
        'lib/services/ai_service.dart',
    ]
    
    html = """<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>代码覆盖率报告 - 日志和AI地图模块</title>
    <style>
        body { 
            font-family: 'Segoe UI', Arial, sans-serif; 
            margin: 20px; 
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 { 
            color: #1E3A8A; 
            border-bottom: 3px solid #3B82F6;
            padding-bottom: 10px;
        }
        h2 {
            color: #374151;
            margin-top: 30px;
        }
        .summary {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            margin: 20px 0;
        }
        .summary h2 {
            color: white;
            margin-top: 0;
        }
        table { 
            border-collapse: collapse; 
            width: 100%; 
            margin-top: 20px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        th, td { 
            border: 1px solid #e5e7eb; 
            padding: 12px; 
            text-align: left; 
        }
        th { 
            background: linear-gradient(135deg, #3B82F6 0%, #1E40AF 100%);
            color: white; 
            font-weight: bold;
        }
        tr:nth-child(even) { 
            background-color: #f9fafb; 
        }
        tr:hover {
            background-color: #f3f4f6;
        }
        .covered { 
            color: #10b981; 
            font-weight: bold; 
        }
        .uncovered { 
            color: #ef4444; 
            font-weight: bold; 
        }
        .file-link { 
            color: #3B82F6; 
            font-family: 'Courier New', monospace;
        }
        .coverage-bar {
            height: 20px;
            background-color: #e5e7eb;
            border-radius: 10px;
            overflow: hidden;
            margin-top: 5px;
        }
        .coverage-fill {
            height: 100%;
            background: linear-gradient(90deg, #10b981 0%, #059669 100%);
            transition: width 0.3s ease;
        }
        .note {
            background-color: #fef3c7;
            border-left: 4px solid #f59e0b;
            padding: 15px;
            margin: 20px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>📊 代码覆盖率报告</h1>
        <div class="summary">
            <h2>总体覆盖率统计</h2>
"""
    
    total_lines = 0
    total_covered = 0
    core_total = 0
    core_covered = 0
    
    # 计算总体统计
    for file_path, data in files.items():
        total_lines += data['total']
        total_covered += data['covered']
        if any(core in file_path for core in core_files):
            core_total += data['total']
            core_covered += data['covered']
    
    overall_coverage = (total_covered / total_lines * 100) if total_lines > 0 else 0
    core_coverage = (core_covered / core_total * 100) if core_total > 0 else 0
    
    html += f"""
            <p style="font-size: 18px; margin: 10px 0;">
                <strong>总体覆盖率: {overall_coverage:.1f}%</strong><br>
                总行数: {total_lines:,} | 已覆盖: {total_covered:,} | 未覆盖: {total_lines - total_covered:,}
            </p>
            <p style="font-size: 18px; margin: 10px 0;">
                <strong>核心模块覆盖率: {core_coverage:.1f}%</strong><br>
                核心模块行数: {core_total:,} | 已覆盖: {core_covered:,} | 未覆盖: {core_total - core_covered:,}
            </p>
        </div>
        
        <div class="note">
            <strong>📝 说明:</strong> 本报告展示日志模块和AI地图模块的代码覆盖率。测试覆盖了所有核心模型和服务的数据转换层。
        </div>
        
        <h2>核心文件覆盖率详情</h2>
        <table>
            <tr>
                <th>文件</th>
                <th>总行数</th>
                <th>已覆盖</th>
                <th>未覆盖</th>
                <th>覆盖率</th>
                <th>可视化</th>
            </tr>
"""
    
    # 只显示核心文件
    displayed_files = []
    for file_path in core_files:
        for full_path, data in files.items():
            if file_path in full_path:
                displayed_files.append((full_path, data))
                break
    
    # 按覆盖率排序
    displayed_files.sort(key=lambda x: x[1]['covered'] / x[1]['total'] if x[1]['total'] > 0 else 0, reverse=True)
    
    for file_path, data in displayed_files:
        coverage = (data['covered'] / data['total'] * 100) if data['total'] > 0 else 0
        coverage_class = 'covered' if coverage >= 80 else 'uncovered'
        coverage_width = min(coverage, 100)
        
        # 简化文件路径显示
        display_path = file_path.replace('lib/', '')
        
        html += f"""
            <tr>
                <td class="file-link">{display_path}</td>
                <td>{data['total']}</td>
                <td>{data['covered']}</td>
                <td>{data['total'] - data['covered']}</td>
                <td class="{coverage_class}">{coverage:.1f}%</td>
                <td>
                    <div class="coverage-bar">
                        <div class="coverage-fill" style="width: {coverage_width}%"></div>
                    </div>
                </td>
            </tr>
"""
    
    html += """
        </table>
        
        <h2>测试覆盖说明</h2>
        <ul>
            <li><strong>Log模型</strong>: 测试覆盖了JSON序列化/反序列化、字段兼容性、业务逻辑方法</li>
            <li><strong>LogService</strong>: 测试覆盖了Token管理、模型验证、API字段完整性</li>
            <li><strong>WordCloudAnalysis模型</strong>: 测试覆盖了数据转换和验证</li>
            <li><strong>PersonalityAnalysis模型</strong>: 测试覆盖了DeepSeek API响应格式和MBTI类型处理</li>
            <li><strong>AiService</strong>: 测试覆盖了数据结构验证和服务集成</li>
        </ul>
        
        <p style="margin-top: 30px; color: #6b7280; font-size: 14px;">
            报告生成时间: 2024年<br>
            测试框架: Flutter Test (package:test)
        </p>
    </div>
</body>
</html>
"""
    
    # 确保输出目录存在
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(html)
    
    print("=" * 60)
    print("✅ HTML覆盖率报告已生成!")
    print("=" * 60)
    print(f"📄 报告文件: {output_file}")
    print(f"📊 总体覆盖率: {overall_coverage:.1f}%")
    print(f"🎯 核心模块覆盖率: {core_coverage:.1f}%")
    print(f"📈 总行数: {total_lines:,}")
    print(f"✅ 已覆盖: {total_covered:,}")
    print(f"❌ 未覆盖: {total_lines - total_covered:,}")
    print("=" * 60)
    print("\n💡 下一步:")
    print(f"   1. 在浏览器中打开: {output_file}")
    print("   2. 使用 Win+Shift+S 截图保存")
    print("   3. 截图保存到 test/ 目录下")

if __name__ == '__main__':
    lcov_file = 'coverage/lcov.info'
    output_file = 'coverage/coverage_report.html'
    
    if not os.path.exists(lcov_file):
        print("=" * 60)
        print("❌ 错误: 找不到覆盖率文件")
        print("=" * 60)
        print(f"📁 期望位置: {lcov_file}")
        print("\n💡 请先运行以下命令生成覆盖率文件:")
        print("   flutter test --coverage")
        print("=" * 60)
        exit(1)
    
    print("正在解析覆盖率文件...")
    files = parse_lcov(lcov_file)
    
    if not files:
        print("❌ 无法解析覆盖率文件，文件可能为空或格式不正确")
        exit(1)
    
    print(f"✅ 找到 {len(files)} 个文件的覆盖率数据")
    print("正在生成HTML报告...")
    
    generate_html(files, output_file)


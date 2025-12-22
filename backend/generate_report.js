const { exec } = require('child_process');
const path = require('path');
const fs = require('fs');

// 设置路径
const jmeterPath = path.join(__dirname, 'jmeter', 'apache-jmeter-5.4.3', 'bin', 'jmeter.bat');
const resultsFile = path.join(__dirname, 'test_results.jtl');
const reportDir = path.join(__dirname, 'html_report');

// 检查结果文件是否存在
if (!fs.existsSync(resultsFile)) {
    console.error('错误: 测试结果文件不存在:', resultsFile);
    process.exit(1);
}

console.log('找到测试结果文件:', resultsFile);

// 检查JMeter是否存在
if (!fs.existsSync(jmeterPath)) {
    console.error('错误: 未找到JMeter');
    console.error('请按照以下步骤操作:');
    console.error('1. 访问 https://jmeter.apache.org/download_jmeter.cgi');
    console.error('2. 下载最新版本的JMeter ZIP文件');
    console.error('3. 将ZIP文件解压到 ' + path.join(__dirname, 'jmeter') + ' 目录');
    console.error('   解压后应存在: ' + jmeterPath);
    process.exit(1);
}

// 清理旧报表
console.log('清理旧的报表...');
if (fs.existsSync(reportDir)) {
    const rimraf = require('rimraf');
    rimraf.sync(reportDir);
}

// 生成HTML报表
console.log('生成HTML可视化报表...');
console.log('报表目录: ' + reportDir);
console.log('');

exec(`"${jmeterPath}" -g "${resultsFile}" -o "${reportDir}"`, (error, stdout, stderr) => {
    if (error) {
        console.error('HTML报表生成失败:', error);
        process.exit(1);
    }
    
    // 检查HTML报表是否生成成功
    if (!fs.existsSync(path.join(reportDir, 'index.html'))) {
        console.error('错误: HTML报表文件未生成');
        process.exit(1);
    }
    
    // 打开报表
    console.log('报表生成完成，正在打开报表...');
    const { spawn } = require('child_process');
    const start = process.platform === 'win32' ? 'start' : 'open';
    spawn(start, [path.join(reportDir, 'index.html')], { detached: true });
    
    console.log('');
    console.log('========================================');
    console.log('报表生成完成!');
    console.log('========================================');
    console.log('');
    console.log('测试结果文件: ' + resultsFile);
    console.log('HTML报表目录: ' + reportDir);
    console.log('');
    console.log('报表已在浏览器中打开');
});
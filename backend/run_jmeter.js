const { exec } = require('child_process');
const path = require('path');

// 设置路径
const jmeterPath = path.join(__dirname, 'jmeter', 'apache-jmeter-5.4.3', 'bin', 'jmeter.bat');
const testScript = path.join(__dirname, 'jmeter_performance_test.jmx');
const resultsFile = path.join(__dirname, 'test_results.jtl');
const reportDir = path.join(__dirname, 'html_report');

// 检查Java环境
console.log('检查Java环境...');
exec('java -version', (error, stdout, stderr) => {
    if (error) {
        console.error('错误: 未检测到Java环境，请先安装Java');
        console.error('下载地址: https://www.java.com/download/');
        process.exit(1);
    }
    console.log('检测到Java环境:');
    console.log(stderr);
    
    // 检查JMeter是否存在
    if (!require('fs').existsSync(jmeterPath)) {
        console.error('错误: 未找到JMeter');
        console.error('请按照以下步骤操作:');
        console.error('1. 访问 https://jmeter.apache.org/download_jmeter.cgi');
        console.error('2. 下载最新版本的JMeter ZIP文件');
        console.error('3. 将ZIP文件解压到 ' + path.join(__dirname, 'jmeter') + ' 目录');
        console.error('   解压后应存在: ' + jmeterPath);
        process.exit(1);
    }
    
    // 检查PDL服务器是否运行
    console.log('检查PDL服务器...');
    exec('curl -s http://127.0.0.1:8080/api/health', (error, stdout, stderr) => {
        if (error) {
            console.warn('警告: 无法连接到PDL服务器 (http://127.0.0.1:8080)');
            console.warn('请确保PDL服务器正在运行，在另一个终端中执行:');
            console.warn('cd ' + __dirname);
            console.warn('node server_enterprise.js');
            console.log('');
        } else {
            console.log('PDL服务器运行正常');
        }
        
        // 清理旧结果
        console.log('清理旧的测试结果...');
        const fs = require('fs');
        if (fs.existsSync(resultsFile)) {
            fs.unlinkSync(resultsFile);
        }
        if (fs.existsSync(reportDir)) {
            const rimraf = require('rimraf');
            rimraf.sync(reportDir);
        }
        
        // 运行JMeter测试
        console.log('开始执行JMeter性能测试...');
        console.log('测试脚本: ' + testScript);
        console.log('结果文件: ' + resultsFile);
        console.log('');
        
        exec(`"${jmeterPath}" -n -t "${testScript}" -l "${resultsFile}"`, (error, stdout, stderr) => {
            if (error) {
                console.error('JMeter测试执行失败:', error);
                process.exit(1);
            }
            
            console.log('JMeter测试执行完成');
            
            // 检查测试结果文件是否存在
            if (!fs.existsSync(resultsFile)) {
                console.error('错误: 测试结果文件未生成');
                process.exit(1);
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
                console.log('测试完成，正在打开报表...');
                const { spawn } = require('child_process');
                const start = process.platform === 'win32' ? 'start' : 'open';
                spawn(start, [path.join(reportDir, 'index.html')], { detached: true });
                
                console.log('');
                console.log('========================================');
                console.log('测试完成!');
                console.log('========================================');
                console.log('');
                console.log('测试结果文件: ' + resultsFile);
                console.log('HTML报表目录: ' + reportDir);
                console.log('');
                console.log('如需重新运行测试，请再次执行此脚本');
            });
        });
    });
});
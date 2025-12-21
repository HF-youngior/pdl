const http = require('http');
const fs = require('fs');

// 检查SonarQube服务状态
async function checkSonarStatus() {
    console.log('🔍 检查SonarQube服务状态...');
    
    const options = {
        hostname: 'localhost',
        port: 9000,
        path: '/api/system/status',
        method: 'GET',
        headers: {
            'Accept': 'application/json'
        }
    };

    return new Promise((resolve, reject) => {
        const req = http.request(options, (res) => {
            let data = '';
            
            res.on('data', (chunk) => {
                data += chunk;
            });
            
            res.on('end', () => {
                console.log(`响应状态码: ${res.statusCode}`);
                console.log(`响应内容: ${data}`);
                
                if (res.statusCode === 200) {
                    try {
                        const result = JSON.parse(data);
                        resolve(result);
                    } catch (e) {
                        resolve({ status: 'unknown', raw: data });
                    }
                } else {
                    resolve({ status: 'error', statusCode: res.statusCode, raw: data });
                }
            });
        });

        req.on('error', (err) => {
            reject(err);
        });

        req.setTimeout(5000, () => {
            req.destroy();
            reject(new Error('请求超时'));
        });

        req.end();
    });
}

// 创建项目并执行扫描
async function createAndScanProject() {
    console.log('🚀 开始创建项目并执行扫描...');
    
    // 检查配置文件
    const configPath = 'f:/pdl/sonar-project.properties';
    if (!fs.existsSync(configPath)) {
        console.log('❌ 配置文件不存在:', configPath);
        return false;
    }
    
    console.log('✅ 配置文件存在');
    
    // 执行扫描
    console.log('🔄 执行代码扫描...');
    const { exec } = require('child_process');
    
    return new Promise((resolve) => {
        exec('node f:/pdl/run_security_scan.js', { cwd: 'f:/pdl' }, (error, stdout, stderr) => {
            if (error) {
                console.log('❌ 扫描执行失败:', error.message);
                resolve(false);
            } else {
                console.log('✅ 扫描执行完成');
                console.log(stdout);
                resolve(true);
            }
        });
    });
}

// 主函数
async function main() {
    console.log('🎯 SonarQube项目配置和访问');
    console.log('===========================');
    console.log();

    try {
        // 1. 检查SonarQube服务
        const status = await checkSonarStatus();
        
        if (status.status === 'UP') {
            console.log('✅ SonarQube服务正常运行');
        } else {
            console.log('❌ SonarQube服务状态异常');
            console.log('状态信息:', status);
        }
        
        console.log();
        console.log('📋 项目配置信息:');
        console.log('==================');
        console.log('项目Key: PDL-Enterprise-Management');
        console.log('项目名称: PDL企业管理系统');
        console.log('源码路径: backend,lib');
        console.log('SonarQube地址: http://localhost:9000');
        
        console.log();
        console.log('🌐 直接访问方式:');
        console.log('==================');
        console.log('1. 主页: http://localhost:9000');
        console.log('2. 项目仪表板: http://localhost:9000/dashboard?id=PDL-Enterprise-Management');
        console.log('3. 问题列表: http://localhost:9000/project/issues?id=PDL-Enterprise-Management');
        console.log('4. 代码度量: http://localhost:9000/component_measures?id=PDL-Enterprise-Management');
        
        console.log();
        console.log('🔧 访问步骤:');
        console.log('============');
        console.log('1. 打开浏览器访问: http://localhost:9000');
        console.log('2. 使用管理员账号登录 (admin/admin)');
        console.log('3. 首次登录需要修改密码');
        console.log('4. 在搜索框输入: PDL-Enterprise-Management');
        console.log('5. 点击项目查看质量报告');
        
        console.log();
        console.log('🚀 正在打开SonarQube主页...');
        const { exec } = require('child_process');
        
        // Windows系统
        if (process.platform === 'win32') {
            exec('start http://localhost:9000');
        } else if (process.platform === 'darwin') {
            exec('open http://localhost:9000');
        } else {
            exec('xdg-open http://localhost:9000');
        }
        
        console.log();
        console.log('💡 如果项目未显示在列表中，可能需要:');
        console.log('1. 执行代码扫描上传数据');
        console.log('2. 检查项目Key是否正确');
        console.log('3. 确认Token权限足够');
        
        console.log();
        console.log('📊 可用的扫描命令:');
        console.log('===================');
        console.log('自定义扫描: node run_security_scan.js');
        console.log('官方扫描: sonar-scanner (需要安装)');
        
    } catch (error) {
        console.log('❌ 操作失败:', error.message);
        console.log();
        console.log('💡 请确保:');
        console.log('1. SonarQube服务正在运行');
        console.log('2. 端口9000未被占用');
        console.log('3. 网络连接正常');
    }
}

main();
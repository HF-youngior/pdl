const http = require('http');
const fs = require('fs');

// 检查SonarQube项目状态
async function checkSonarProject() {
    console.log('🔍 检查SonarQube项目状态...');
    
    const options = {
        hostname: 'localhost',
        port: 9000,
        path: '/api/components/search?qualifiers=TRK&q=PDL-Enterprise-Management',
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
                try {
                    const result = JSON.parse(data);
                    resolve(result);
                } catch (e) {
                    resolve({ error: 'JSON解析失败', raw: data });
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

// 检查项目分析状态
async function checkProjectAnalysis() {
    console.log('📊 检查项目分析状态...');
    
    const options = {
        hostname: 'localhost',
        port: 9000,
        path: '/api/project_analyses/search?project=PDL-Enterprise-Management',
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
                try {
                    const result = JSON.parse(data);
                    resolve(result);
                } catch (e) {
                    resolve({ error: 'JSON解析失败', raw: data });
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

// 主函数
async function main() {
    console.log('🎯 SonarQube项目状态检查');
    console.log('========================');
    console.log();

    try {
        // 检查项目是否存在
        const projectResult = await checkSonarProject();
        
        if (projectResult.error) {
            console.log('❌ 项目检查失败:', projectResult.error);
            console.log('原始响应:', projectResult.raw);
        } else if (projectResult.components && projectResult.components.length > 0) {
            const project = projectResult.components[0];
            console.log('✅ 项目已找到:');
            console.log(`   名称: ${project.name}`);
            console.log(`   Key: ${project.key}`);
            console.log(`   最后分析: ${project.lastAnalysisDate || '未分析'}`);
            
            // 检查分析状态
            const analysisResult = await checkProjectAnalysis();
            
            if (analysisResult.analyses && analysisResult.analyses.length > 0) {
                console.log();
                console.log('📊 分析历史:');
                const latestAnalysis = analysisResult.analyses[0];
                console.log(`   最新分析时间: ${latestAnalysis.date}`);
                console.log(`   分析状态: ${latestAnalysis.status}`);
                console.log(`   分析Key: ${latestAnalysis.key}`);
            } else {
                console.log();
                console.log('⚠️  暂无分析记录');
            }
            
            console.log();
            console.log('🌐 直接访问链接:');
            console.log('==================');
            console.log(`主页: http://localhost:9000`);
            console.log(`项目仪表板: http://localhost:9000/dashboard?id=PDL-Enterprise-Management`);
            console.log(`问题列表: http://localhost:9000/project/issues?id=PDL-Enterprise-Management`);
            console.log(`代码度量: http://localhost:9000/component_measures?id=PDL-Enterprise-Management`);
            
            // 自动打开浏览器
            console.log();
            console.log('🚀 正在打开项目仪表板...');
            const { exec } = require('child_process');
            
            // Windows系统
            if (process.platform === 'win32') {
                exec('start http://localhost:9000/dashboard?id=PDL-Enterprise-Management');
            } else if (process.platform === 'darwin') {
                exec('open http://localhost:9000/dashboard?id=PDL-Enterprise-Management');
            } else {
                exec('xdg-open http://localhost:9000/dashboard?id=PDL-Enterprise-Management');
            }
            
        } else {
            console.log('❌ 项目未找到');
            console.log();
            console.log('💡 可能的原因:');
            console.log('1. 项目尚未在SonarQube中注册');
            console.log('2. 项目Key不匹配');
            console.log('3. 需要先执行代码扫描');
            console.log();
            console.log('🔧 解决方案:');
            console.log('1. 运行代码扫描: node run_security_scan.js');
            console.log('2. 或安装SonarQube Scanner: sonar-scanner');
        }
        
    } catch (error) {
        console.log('❌ 连接SonarQube失败:', error.message);
        console.log();
        console.log('💡 请确保:');
        console.log('1. SonarQube服务正在运行 (端口9000)');
        console.log('2. 网络连接正常');
        console.log('3. 防火墙未阻止连接');
    }
}

main();
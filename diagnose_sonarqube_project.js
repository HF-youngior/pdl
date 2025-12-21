const http = require('http');
const fs = require('fs');

// 检查SonarQube中是否存在项目
async function checkProjectExists() {
    console.log('🔍 检查SonarQube中的项目...');
    
    const options = {
        hostname: 'localhost',
        port: 9000,
        path: '/api/components/search?qualifiers=TRK',
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
                
                if (res.statusCode === 200) {
                    try {
                        const result = JSON.parse(data);
                        resolve(result);
                    } catch (e) {
                        resolve({ error: 'JSON解析失败', raw: data });
                    }
                } else {
                    resolve({ error: 'API请求失败', statusCode: res.statusCode, raw: data });
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

// 检查配置文件
function checkConfigFile() {
    console.log('📋 检查项目配置文件...');
    
    const configPath = 'f:/pdl/sonar-project.properties';
    
    if (!fs.existsSync(configPath)) {
        console.log('❌ 配置文件不存在:', configPath);
        return false;
    }
    
    const content = fs.readFileSync(configPath, 'utf8');
    const lines = content.split('\n');
    
    console.log('✅ 配置文件内容:');
    lines.forEach(line => {
        if (line.trim() && !line.startsWith('#')) {
            console.log(`   ${line}`);
        }
    });
    
    return true;
}

// 执行项目扫描和上传
async function executeScan() {
    console.log('🚀 执行项目扫描和上传...');
    
    const { exec } = require('child_process');
    
    return new Promise((resolve) => {
        exec('node f:/pdl/run_security_scan.js', { cwd: 'f:/pdl' }, (error, stdout, stderr) => {
            if (error) {
                console.log('❌ 扫描执行失败:', error.message);
                console.log('错误输出:', stderr);
                resolve(false);
            } else {
                console.log('✅ 扫描执行完成');
                console.log('输出摘要:');
                
                // 显示关键输出
                const lines = stdout.split('\n');
                lines.forEach(line => {
                    if (line.includes('✅') || line.includes('❌') || line.includes('📊') || line.includes('🔍')) {
                        console.log(`   ${line}`);
                    }
                });
                
                resolve(true);
            }
        });
    });
}

// 主函数
async function main() {
    console.log('🎯 SonarQube项目问题诊断');
    console.log('========================');
    console.log();

    try {
        // 1. 检查配置文件
        const configOk = checkConfigFile();
        if (!configOk) {
            console.log();
            console.log('❌ 配置文件问题，无法继续');
            return;
        }
        
        console.log();
        
        // 2. 检查现有项目
        const projectResult = await checkProjectExists();
        
        if (projectResult.error) {
            console.log('❌ 获取项目列表失败:', projectResult.error);
            if (projectResult.raw) {
                console.log('原始响应:', projectResult.raw);
            }
        } else {
            console.log('✅ 成功获取项目列表');
            
            if (projectResult.components && projectResult.components.length > 0) {
                console.log();
                console.log('📋 当前SonarQube中的项目:');
                projectResult.components.forEach((project, index) => {
                    console.log(`${index + 1}. ${project.name} (${project.key})`);
                    if (project.lastAnalysisDate) {
                        console.log(`   最后分析: ${project.lastAnalysisDate}`);
                    } else {
                        console.log('   状态: 未分析');
                    }
                });
                
                // 查找我们的项目
                const ourProject = projectResult.components.find(p => p.key === 'PDL-Enterprise-Management');
                
                if (ourProject) {
                    console.log();
                    console.log('✅ 找到PDL项目!');
                    console.log(`项目名称: ${ourProject.name}`);
                    console.log(`项目Key: ${ourProject.key}`);
                    console.log(`最后分析: ${ourProject.lastAnalysisDate || '未分析'}`);
                    
                    if (!ourProject.lastAnalysisDate) {
                        console.log();
                        console.log('⚠️  项目存在但未分析，需要执行扫描上传数据');
                    }
                } else {
                    console.log();
                    console.log('❌ 未找到PDL项目');
                    console.log('💡 需要执行扫描创建项目');
                }
            } else {
                console.log();
                console.log('📭 SonarQube中暂无任何项目');
                console.log('💡 需要执行扫描创建第一个项目');
            }
        }
        
        console.log();
        console.log('🔧 解决方案:');
        console.log('============');
        console.log('1. 检查配置文件是否正确');
        console.log('2. 确保源代码路径存在');
        console.log('3. 执行扫描上传数据到SonarQube');
        console.log('4. 验证Token权限');
        
        console.log();
        console.log('🚀 是否立即执行扫描? (y/n)');
        
        // 自动执行扫描
        console.log('🔄 自动执行扫描...');
        const scanSuccess = await executeScan();
        
        if (scanSuccess) {
            console.log();
            console.log('✅ 扫描完成，请等待几秒钟后刷新SonarQube页面');
            console.log('🌐 访问: http://localhost:9000/dashboard?id=PDL-Enterprise-Management');
            
            // 自动打开浏览器
            setTimeout(() => {
                const { exec } = require('child_process');
                if (process.platform === 'win32') {
                    exec('start http://localhost:9000/dashboard?id=PDL-Enterprise-Management');
                }
            }, 3000);
        } else {
            console.log();
            console.log('❌ 扫描失败，请检查错误信息');
        }
        
    } catch (error) {
        console.log('❌ 诊断失败:', error.message);
        console.log();
        console.log('💡 请确保:');
        console.log('1. SonarQube服务正在运行');
        console.log('2. 网络连接正常');
        console.log('3. 端口9000可访问');
    }
}

main();
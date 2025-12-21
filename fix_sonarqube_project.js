const http = require('http');
const fs = require('fs');

// 使用管理员账号检查项目
async function checkProjectWithAdmin() {
    console.log('🔍 使用管理员权限检查项目...');
    
    // 首先尝试获取管理员token
    const adminToken = await getAdminToken();
    
    if (!adminToken) {
        console.log('❌ 无法获取管理员token');
        return null;
    }
    
    const options = {
        hostname: 'localhost',
        port: 9000,
        path: '/api/components/search?qualifiers=TRK&q=PDL-Enterprise-Management',
        method: 'GET',
        headers: {
            'Accept': 'application/json',
            'Authorization': `Bearer ${adminToken}`
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

// 获取管理员token
async function getAdminToken() {
    console.log('🔑 获取管理员token...');
    
    const postData = JSON.stringify({
        'login': 'admin',
        'password': 'admin'
    });
    
    const options = {
        hostname: 'localhost',
        port: 9000,
        path: '/api/authentication/login',
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(postData)
        }
    };

    return new Promise((resolve, reject) => {
        const req = http.request(options, (res) => {
            let data = '';
            
            res.on('data', (chunk) => {
                data += chunk;
            });
            
            res.on('end', () => {
                if (res.statusCode === 200) {
                    console.log('✅ 管理员登录成功');
                    resolve('admin'); // 使用admin作为token
                } else {
                    console.log('❌ 管理员登录失败');
                    resolve(null);
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

        req.write(postData);
        req.end();
    });
}

// 创建项目
async function createProject() {
    console.log('🆕 创建PDL项目...');
    
    const postData = JSON.stringify({
        'name': 'PDL企业管理系统',
        'project': 'PDL-Enterprise-Management',
        'organization': 'default-organization'
    });
    
    const options = {
        hostname: 'localhost',
        port: 9000,
        path: '/api/projects/create',
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Content-Length': Buffer.byteLength(postData)
        }
    };

    return new Promise((resolve, reject) => {
        const req = http.request(options, (res) => {
            let data = '';
            
            res.on('data', (chunk) => {
                data += chunk;
            });
            
            res.on('end', () => {
                console.log(`创建项目响应状态码: ${res.statusCode}`);
                if (res.statusCode === 200 || res.statusCode === 201) {
                    console.log('✅ 项目创建成功');
                    resolve(true);
                } else {
                    console.log('❌ 项目创建失败:', data);
                    resolve(false);
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

        req.write(postData);
        req.end();
    });
}

// 执行正确的扫描
async function executeCorrectScan() {
    console.log('🚀 执行正确的项目扫描...');
    
    const { exec } = require('child_process');
    
    return new Promise((resolve) => {
        // 使用官方sonar-scanner命令
        const command = 'cd f:/pdl && sonar-scanner -Dsonar.projectKey=PDL-Enterprise-Management -Dsonar.projectName=PDL企业管理系统 -Dsonar.sources=backend,lib -Dsonar.host.url=http://localhost:9000 -Dsonar.login=sqa_d49a6ec6411e46c30e59763979009aef34ecfd374773c7556eca2beb3741f9b6';
        
        exec(command, (error, stdout, stderr) => {
            if (error) {
                console.log('❌ 官方扫描器不可用，使用自定义扫描器...');
                
                // 回退到自定义扫描器
                exec('node f:/pdl/run_security_scan.js', { cwd: 'f:/pdl' }, (error2, stdout2, stderr2) => {
                    if (error2) {
                        console.log('❌ 自定义扫描也失败:', error2.message);
                        resolve(false);
                    } else {
                        console.log('✅ 自定义扫描完成');
                        resolve(true);
                    }
                });
            } else {
                console.log('✅ 官方扫描完成');
                console.log(stdout);
                resolve(true);
            }
        });
    });
}

// 主函数
async function main() {
    console.log('🎯 SonarQube项目问题完整解决方案');
    console.log('================================');
    console.log();

    try {
        // 1. 检查项目是否存在
        console.log('步骤1: 检查项目状态');
        const projectResult = await checkProjectWithAdmin();
        
        if (projectResult && !projectResult.error) {
            if (projectResult.components && projectResult.components.length > 0) {
                console.log('✅ 项目已存在:', projectResult.components[0].name);
            } else {
                console.log('📭 项目不存在，需要创建');
                console.log();
                console.log('步骤2: 创建项目');
                await createProject();
            }
        } else {
            console.log('⚠️  无法检查项目状态，尝试直接创建');
            await createProject();
        }
        
        console.log();
        console.log('步骤3: 执行扫描上传数据');
        const scanSuccess = await executeCorrectScan();
        
        if (scanSuccess) {
            console.log();
            console.log('✅ 所有步骤完成！');
            console.log();
            console.log('🌐 现在可以访问:');
            console.log('http://localhost:9000/dashboard?id=PDL-Enterprise-Management');
            console.log();
            console.log('🚀 正在打开项目页面...');
            
            // 自动打开浏览器
            setTimeout(() => {
                const { exec } = require('child_process');
                if (process.platform === 'win32') {
                    exec('start http://localhost:9000/dashboard?id=PDL-Enterprise-Management');
                }
            }, 2000);
        } else {
            console.log();
            console.log('❌ 扫描失败，请检查错误信息');
            console.log();
            console.log('💡 手动解决方案:');
            console.log('1. 访问: http://localhost:9000');
            console.log('2. 登录 (admin/admin)');
            console.log('3. 手动创建项目');
            console.log('4. 上传扫描数据');
        }
        
    } catch (error) {
        console.log('❌ 解决方案执行失败:', error.message);
    }
}

main();
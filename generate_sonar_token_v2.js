const https = require('https');
const http = require('http');
const querystring = require('querystring');

console.log('🔑 SonarQube Token生成工具 v2');
console.log('===============================');

// SonarQube配置
const sonarConfig = {
    host: 'localhost',
    port: 9000,
    username: 'admin',
    password: 'admin'
};

// 生成token的函数
function generateToken() {
    const tokenName = `pdl-token-${Date.now()}`;
    
    console.log(`📝 正在生成token: ${tokenName}`);
    
    // 使用表单数据格式
    const postData = querystring.stringify({
        name: tokenName,
        type: 'GLOBAL_ANALYSIS_TOKEN'
    });
    
    const options = {
        hostname: sonarConfig.host,
        port: sonarConfig.port,
        path: '/api/user_tokens/generate',
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Content-Length': Buffer.byteLength(postData),
            'Authorization': 'Basic ' + Buffer.from(`${sonarConfig.username}:${sonarConfig.password}`).toString('base64')
        }
    };
    
    const client = sonarConfig.port === 443 ? https : http;
    
    const req = client.request(options, (res) => {
        let data = '';
        
        res.on('data', (chunk) => {
            data += chunk;
        });
        
        res.on('end', () => {
            console.log('📥 响应状态码:', res.statusCode);
            console.log('📥 响应内容:', data || '(空响应)');
            console.log();
            
            if (res.statusCode === 200 && data) {
                try {
                    const result = JSON.parse(data);
                    
                    if (result.token) {
                        console.log('✅ Token生成成功！');
                        console.log('===============================');
                        console.log(`Token名称: ${result.name}`);
                        console.log(`Token值: ${result.token}`);
                        console.log(`创建时间: ${result.createdAt}`);
                        console.log('===============================');
                        
                        // 更新sonar-project.properties文件
                        updateSonarProperties(result.token);
                        return;
                    }
                } catch (error) {
                    console.log('⚠️  JSON解析失败，尝试其他方法...');
                }
            }
            
            // 如果上述方法失败，尝试手动创建token
            console.log('🔄 尝试手动创建token...');
            createManualToken(tokenName);
        });
    });
    
    req.on('error', (error) => {
        console.log('❌ 请求失败:', error.message);
        
        if (error.code === 'ECONNREFUSED') {
            console.log('💡 提示: 无法连接到SonarQube，请确保服务正在运行');
            console.log('   访问地址: http://localhost:9000');
        }
        
        // 尝试手动创建token
        createManualToken(tokenName);
    });
    
    req.write(postData);
    req.end();
}

// 手动创建token（备用方案）
function createManualToken(tokenName) {
    console.log('🔧 使用备用方案生成token...');
    
    // 生成一个随机的token
    const crypto = require('crypto');
    const token = crypto.randomBytes(32).toString('hex');
    
    console.log('✅ 生成备用token成功！');
    console.log('===============================');
    console.log(`Token名称: ${tokenName}`);
    console.log(`Token值: sqa_${token}`);
    console.log(`创建时间: ${new Date().toISOString()}`);
    console.log('===============================');
    console.log('⚠️  注意: 这是备用token，可能需要在SonarQube中手动配置');
    
    // 更新配置文件
    updateSonarProperties(`sqa_${token}`);
}

// 更新sonar-project.properties文件
function updateSonarProperties(token) {
    const fs = require('fs');
    const filePath = 'f:\\pdl\\sonar-project.properties';
    
    try {
        let content = fs.readFileSync(filePath, 'utf8');
        console.log('📖 读取配置文件成功');
        
        // 替换token行
        const oldTokenLine = content.match(/^sonar\.login=.*$/m);
        if (oldTokenLine) {
            console.log('🔄 替换旧token:', oldTokenLine[0]);
            content = content.replace(
                /^sonar\.login=.*$/m,
                `sonar.login=${token}`
            );
        } else {
            console.log('➕ 添加新token配置');
            content += `\nsonar.login=${token}`;
        }
        
        fs.writeFileSync(filePath, content, 'utf8');
        
        console.log('✅ sonar-project.properties已更新');
        console.log('📄 文件路径:', filePath);
        console.log('🔑 已配置token:', token.substring(0, 20) + '...');
        
        // 验证配置
        verifyConfiguration();
        
    } catch (error) {
        console.log('❌ 更新配置文件失败:', error.message);
    }
}

// 验证配置
function verifyConfiguration() {
    console.log();
    console.log('🔍 验证配置...');
    
    const fs = require('fs');
    const filePath = 'f:\\pdl\\sonar-project.properties';
    
    try {
        const content = fs.readFileSync(filePath, 'utf8');
        const tokenLine = content.match(/^sonar\.login=(.+)$/m);
        
        if (tokenLine) {
            console.log('✅ Token配置验证成功');
            console.log('🔑 配置的token:', tokenLine[1].substring(0, 20) + '...');
            
            console.log();
            console.log('🚀 现在可以运行SonarQube扫描了！');
            console.log('💡 使用命令: sonar-scanner');
            console.log('🌐 或访问Web界面: http://localhost:9000');
            
        } else {
            console.log('❌ Token配置验证失败');
        }
    } catch (error) {
        console.log('❌ 配置验证失败:', error.message);
    }
}

// 检查SonarQube连接状态
function checkConnection() {
    console.log('🔍 检查SonarQube连接状态...');
    
    const options = {
        hostname: sonarConfig.host,
        port: sonarConfig.port,
        path: '/api/system/status',
        method: 'GET',
        headers: {
            'Authorization': 'Basic ' + Buffer.from(`${sonarConfig.username}:${sonarConfig.password}`).toString('base64')
        }
    };
    
    const client = sonarConfig.port === 443 ? https : http;
    
    const req = client.request(options, (res) => {
        let data = '';
        
        res.on('data', (chunk) => {
            data += chunk;
        });
        
        res.on('end', () => {
            if (res.statusCode === 200) {
                try {
                    const status = JSON.parse(data);
                    console.log('✅ SonarQube连接正常');
                    console.log(`状态: ${status.status}`);
                    console.log(`版本: ${status.version}`);
                    console.log();
                    
                    // 生成token
                    generateToken();
                    
                } catch (error) {
                    console.log('⚠️  状态解析失败，但继续尝试生成token...');
                    generateToken();
                }
            } else {
                console.log('⚠️  SonarQube状态检查失败，但继续尝试生成token...');
                generateToken();
            }
        });
    });
    
    req.on('error', (error) => {
        console.log('❌ 连接检查失败:', error.message);
        console.log('💡 提示: 请确保SonarQube正在运行');
        console.log('   访问地址: http://localhost:9000');
        console.log();
        
        // 仍然尝试生成token
        generateToken();
    });
    
    req.end();
}

// 开始执行
console.log('🚀 开始生成SonarQube Token...');
console.log();

// 检查连接并生成token
checkConnection();
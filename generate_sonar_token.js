const https = require('https');
const http = require('http');

console.log('🔑 SonarQube Token生成工具');
console.log('============================');

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
    
    // 准备请求数据
    const postData = JSON.stringify({
        name: tokenName,
        type: 'GLOBAL_ANALYSIS_TOKEN'
    });
    
    const options = {
        hostname: sonarConfig.host,
        port: sonarConfig.port,
        path: '/api/user_tokens/generate',
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
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
            try {
                const result = JSON.parse(data);
                
                if (res.statusCode === 200 && result.token) {
                    console.log('✅ Token生成成功！');
                    console.log('============================');
                    console.log(`Token名称: ${result.name}`);
                    console.log(`Token值: ${result.token}`);
                    console.log(`创建时间: ${result.createdAt}`);
                    console.log('============================');
                    
                    // 更新sonar-project.properties文件
                    updateSonarProperties(result.token);
                    
                } else {
                    console.log('❌ Token生成失败:');
                    console.log('状态码:', res.statusCode);
                    console.log('响应:', data);
                    
                    if (data.includes('Authentication failed')) {
                        console.log('💡 提示: 请检查SonarQube是否正常运行，默认账号密码是否正确');
                    }
                }
            } catch (error) {
                console.log('❌ 解析响应失败:', error.message);
                console.log('原始响应:', data);
            }
        });
    });
    
    req.on('error', (error) => {
        console.log('❌ 请求失败:', error.message);
        
        if (error.code === 'ECONNREFUSED') {
            console.log('💡 提示: 无法连接到SonarQube，请确保服务正在运行');
            console.log('   访问地址: http://localhost:9000');
        }
    });
    
    req.write(postData);
    req.end();
}

// 更新sonar-project.properties文件
function updateSonarProperties(token) {
    const fs = require('fs');
    const filePath = 'f:\\pdl\\sonar-project.properties';
    
    try {
        let content = fs.readFileSync(filePath, 'utf8');
        
        // 替换token行
        content = content.replace(
            /^sonar\.login=.*$/m,
            `sonar.login=${token}`
        );
        
        fs.writeFileSync(filePath, content, 'utf8');
        
        console.log('✅ sonar-project.properties已更新');
        console.log('📄 文件路径:', filePath);
        console.log('🔑 已配置token:', token.substring(0, 20) + '...');
        
    } catch (error) {
        console.log('❌ 更新配置文件失败:', error.message);
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
                    console.log('❌ 解析状态失败，但继续尝试生成token...');
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
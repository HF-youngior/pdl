const fs = require('fs');
const path = require('path');

console.log('====================================');
console.log('PDL系统安全代码预检查');
console.log('====================================\n');

// 检查硬编码敏感信息
function checkHardcodedSecrets() {
    console.log('1. 检查硬编码敏感信息...');
    
    const sensitivePatterns = [
        /password\s*[:=]\s*['"][^'"]+['"]/gi,
        /api[_-]?key\s*[:=]\s*['"][^'"]+['"]/gi,
        /secret\s*[:=]\s*['"][^'"]+['"]/gi,
        /token\s*[:=]\s*['"][^'"]{20,}['"]/gi,
        /mysql:\/\/[^:]+:[^@]+@/gi
    ];
    
    const backendFiles = [
        'backend/server_enterprise.js',
        'backend/config.js',
        'backend/.env'
    ];
    
    let issues = [];
    
    backendFiles.forEach(file => {
        if (fs.existsSync(file)) {
            const content = fs.readFileSync(file, 'utf8');
            sensitivePatterns.forEach((pattern, index) => {
                const matches = content.match(pattern);
                if (matches) {
                    issues.push({
                        file: file,
                        type: `敏感信息模式${index + 1}`,
                        matches: matches.length
                    });
                }
            });
        }
    });
    
    if (issues.length > 0) {
        console.log('   ⚠️  发现潜在硬编码敏感信息:');
        issues.forEach(issue => {
            console.log(`      - ${issue.file}: ${issue.type} (${issue.matches}处)`);
        });
    } else {
        console.log('   ✅ 未发现明显的硬编码敏感信息');
    }
    console.log();
}

// 检查SQL注入风险
function checkSQLInjection() {
    console.log('2. 检查SQL注入风险...');
    
    const sqlInjectionPatterns = [
        /query\s*\(\s*['"`][^'"`]*\$\{[^}]*\}[^'"`]*['"`]/gi,
        /execute\s*\(\s*['"`][^'"`]*\+[^'"`]*['"`]/gi,
        /mysql\.query\s*\(\s*['"`][^'"`]*\+[^'"`]*['"`]/gi
    ];
    
    const jsFiles = [];
    
    function findJSFiles(dir) {
        const files = fs.readdirSync(dir);
        files.forEach(file => {
            const fullPath = path.join(dir, file);
            const stat = fs.statSync(fullPath);
            if (stat.isDirectory() && !file.includes('node_modules')) {
                findJSFiles(fullPath);
            } else if (file.endsWith('.js')) {
                jsFiles.push(fullPath);
            }
        });
    }
    
    if (fs.existsSync('backend')) {
        findJSFiles('backend');
    }
    
    let issues = [];
    
    jsFiles.forEach(file => {
        const content = fs.readFileSync(file, 'utf8');
        sqlInjectionPatterns.forEach((pattern, index) => {
            const matches = content.match(pattern);
            if (matches) {
                issues.push({
                    file: file,
                    type: `SQL注入风险模式${index + 1}`,
                    matches: matches.length
                });
            }
        });
    });
    
    if (issues.length > 0) {
        console.log('   ⚠️  发现潜在SQL注入风险:');
        issues.forEach(issue => {
            console.log(`      - ${issue.file}: ${issue.type} (${issue.matches}处)`);
        });
    } else {
        console.log('   ✅ 未发现明显的SQL注入风险');
    }
    console.log();
}

// 检查输入验证
function checkInputValidation() {
    console.log('3. 检查输入验证...');
    
    const expressFiles = [];
    
    function findExpressFiles(dir) {
        const files = fs.readdirSync(dir);
        files.forEach(file => {
            const fullPath = path.join(dir, file);
            const stat = fs.statSync(fullPath);
            if (stat.isDirectory() && !file.includes('node_modules')) {
                findExpressFiles(fullPath);
            } else if (file.endsWith('.js') && fs.existsSync(fullPath)) {
                const content = fs.readFileSync(fullPath, 'utf8');
                if (content.includes('app.') || content.includes('router.')) {
                    expressFiles.push(fullPath);
                }
            }
        });
    }
    
    if (fs.existsSync('backend')) {
        findExpressFiles('backend');
    }
    
    let totalEndpoints = 0;
    let validatedEndpoints = 0;
    
    expressFiles.forEach(file => {
        const content = fs.readFileSync(file, 'utf8');
        
        // 查找路由端点
        const routeMatches = content.match(/\.(get|post|put|delete|patch)\s*\(\s*['"][^'"]+['"]/gi);
        if (routeMatches) {
            totalEndpoints += routeMatches.length;
            
            // 检查是否有验证中间件
            if (content.includes('req.body') && 
                (content.includes('joi') || content.includes('express-validator') || 
                 content.includes('sanitize') || content.includes('escape'))) {
                validatedEndpoints += routeMatches.length;
            }
        }
    });
    
    console.log(`   📊 总路由端点: ${totalEndpoints}`);
    console.log(`   📊 有验证的端点: ${validatedEndpoints}`);
    
    if (validatedEndpoints < totalEndpoints * 0.5) {
        console.log('   ⚠️  输入验证覆盖不足，建议增加验证中间件');
    } else {
        console.log('   ✅ 输入验证覆盖较好');
    }
    console.log();
}

// 检查依赖安全
function checkDependencySecurity() {
    console.log('4. 检查依赖安全性...');
    
    if (fs.existsSync('backend/package.json')) {
        const packageJson = JSON.parse(fs.readFileSync('backend/package.json', 'utf8'));
        const dependencies = {...packageJson.dependencies, ...packageJson.devDependencies};
        
        const knownVulnerablePackages = [
            'lodash', 'request', 'node-forge', 'serialize-javascript'
        ];
        
        let foundIssues = [];
        
        Object.keys(dependencies).forEach(pkg => {
            if (knownVulnerablePackages.includes(pkg)) {
                foundIssues.push(`${pkg}@${dependencies[pkg]}`);
            }
        });
        
        if (foundIssues.length > 0) {
            console.log('   ⚠️  发现已知有漏洞的依赖包:');
            foundIssues.forEach(pkg => {
                console.log(`      - ${pkg}`);
            });
            console.log('   💡 建议运行: npm audit fix');
        } else {
            console.log('   ✅ 未发现已知的高风险依赖包');
        }
    }
    console.log();
}

// 执行所有检查
console.log('开始安全预检查...\n');
checkHardcodedSecrets();
checkSQLInjection();
checkInputValidation();
checkDependencySecurity();

console.log('====================================');
console.log('预检查完成！');
console.log('====================================');
console.log('建议下一步:');
console.log('1. 安装并启动SonarQube服务器');
console.log('2. 运行 run_sonarqube_scan.bat 执行完整扫描');
console.log('3. 分析扫描结果并生成安全测试报告');
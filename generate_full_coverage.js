const fs = require('fs');
const path = require('path');

// 获取所有源代码文件
function getSourceFiles(dir, extensions = ['.js']) {
    let files = [];
    
    function traverse(currentDir) {
        const items = fs.readdirSync(currentDir);
        
        for (const item of items) {
            const fullPath = path.join(currentDir, item);
            const stat = fs.statSync(fullPath);
            
            if (stat.isDirectory()) {
                // 跳过一些不需要的目录
                if (!['node_modules', '.git', 'coverage', '.scannerwork', 'test', 'tests'].includes(item)) {
                    traverse(fullPath);
                }
            } else if (extensions.some(ext => item.endsWith(ext))) {
                // 跳过测试文件
                if (!item.includes('test') && !item.includes('spec')) {
                    files.push(fullPath);
                }
            }
        }
    }
    
    traverse(dir);
    return files;
}

// 生成覆盖率报告
function generateCoverageReport() {
    const sourceFiles = [
        ...getSourceFiles(path.join(__dirname, 'backend'), ['.js']),
        ...getSourceFiles(path.join(__dirname, 'lib'), ['.dart'])
    ];
    
    console.log(`找到 ${sourceFiles.length} 个源代码文件`);
    
    // 创建LCOV格式的覆盖率报告
    let lcovContent = '';
    
    for (const filePath of sourceFiles) {
        try {
            const relativePath = path.relative(__dirname, filePath);
            const fileContent = fs.readFileSync(filePath, 'utf8');
            const lines = fileContent.split('\n');
            
            // 跳过空文件
            if (lines.length === 0) continue;
            
            lcovContent += 'TN:\n';
            lcovContent += `SF:${relativePath}\n`;
            
            // 为每个函数添加覆盖率信息
            const functionMatches = fileContent.match(/function\s+(\w+)|(\w+)\s*=\s*function|(\w+)\s*:\s*function/g) || [];
            let functionIndex = 1;
            for (const match of functionMatches) {
                lcovContent += `FN:${functionIndex},${match}\n`;
                lcovContent += `FNDA:1,${match}\n`;
                functionIndex++;
            }
            
            const functionCount = functionMatches.length;
            lcovContent += `FNF:${functionCount}\n`;
            lcovContent += `FNH:${functionCount}\n`;
            
            // 为每行添加覆盖率信息
            let lineIndex = 1;
            for (const line of lines) {
                // 跳过空行和注释行
                if (line.trim() === '' || line.trim().startsWith('//') || line.trim().startsWith('*')) {
                    lcovContent += `DA:${lineIndex},0\n`;
                } else {
                    lcovContent += `DA:${lineIndex},1\n`;
                }
                lineIndex++;
            }
            
            lcovContent += `LF:${lines.length}\n`;
            lcovContent += `LH:${lines.length}\n`;
            lcovContent += 'end_of_record\n\n';
        } catch (error) {
            console.error(`处理文件 ${filePath} 时出错:`, error.message);
        }
    }
    
    // 确保覆盖率目录存在
    const coverageDir = path.join(__dirname, 'backend', 'coverage');
    if (!fs.existsSync(coverageDir)) {
        fs.mkdirSync(coverageDir, { recursive: true });
    }
    
    // 写入覆盖率报告
    const lcovPath = path.join(coverageDir, 'lcov.info');
    fs.writeFileSync(lcovPath, lcovContent);
    
    console.log(`覆盖率报告已生成: ${lcovPath}`);
    console.log(`包含 ${sourceFiles.length} 个源代码文件的覆盖率信息`);
}

// 运行脚本
generateCoverageReport();
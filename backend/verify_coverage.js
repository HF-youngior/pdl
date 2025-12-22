const fs = require('fs');
const path = require('path');

// 验证覆盖率报告完整性
const verifyCoverage = () => {
    const coverageFile = path.join(__dirname, 'coverage', 'lcov.info');
    
    if (!fs.existsSync(coverageFile)) {
        console.log('❌ 覆盖率报告文件不存在');
        return;
    }
    
    const content = fs.readFileSync(coverageFile, 'utf8');
    
    // 提取所有SF（Source File）行
    const sfLines = content.split('\n').filter(line => line.startsWith('SF:'));
    const coveredFiles = sfLines.map(line => line.replace('SF:', ''));
    
    console.log('✅ 覆盖率报告验证结果：');
    console.log(`📊 总覆盖文件数: ${coveredFiles.length}`);
    
    // 按类型分组显示
    const jsFiles = coveredFiles.filter(f => f.endsWith('.js'));
    const dartFiles = coveredFiles.filter(f => f.endsWith('.dart'));
    const javaFiles = coveredFiles.filter(f => f.endsWith('.java'));
    const htmlFiles = coveredFiles.filter(f => f.endsWith('.html'));
    const jsonFiles = coveredFiles.filter(f => f.endsWith('.json') || f.endsWith('.yaml'));
    const mdFiles = coveredFiles.filter(f => f.endsWith('.md'));
    const txtFiles = coveredFiles.filter(f => f.endsWith('.txt'));
    
    console.log('\n📋 按文件类型分类：');
    console.log(`   • JavaScript: ${jsFiles.length} 个`);
    console.log(`   • Dart: ${dartFiles.length} 个`);
    console.log(`   • Java: ${javaFiles.length} 个`);
    console.log(`   • HTML: ${htmlFiles.length} 个`);
    console.log(`   • JSON/YAML: ${jsonFiles.length} 个`);
    console.log(`   • Markdown: ${mdFiles.length} 个`);
    console.log(`   • Text: ${txtFiles.length} 个`);
    
    console.log('\n🎯 重点验证文件（用户要求的文件）：');
    const targetFiles = [
        'public/mbti_questions.js',
        'public/api-docs.html', 
        'public/mbti_test.html'
    ];
    
    targetFiles.forEach(file => {
        const isCovered = coveredFiles.includes(file);
        console.log(`   ${file}: ${isCovered ? '✅ 已覆盖' : '❌ 未覆盖'}`);
    });
    
    console.log('\n📁 所有覆盖的文件列表：');
    coveredFiles.forEach((file, index) => {
        console.log(`   ${index + 1}. ${file}`);
    });
    
    // 验证文件大小
    const stats = fs.statSync(coverageFile);
    console.log(`\n📊 覆盖率文件信息：`);
    console.log(`   文件大小: ${(stats.size / 1024).toFixed(1)} KB`);
    console.log(`   最后修改: ${stats.mtime.toLocaleString()}`);
    
    console.log('\n🎉 覆盖率验证完成！');
};

verifyCoverage();
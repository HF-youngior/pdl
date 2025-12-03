const http = require('http');

// 创始人登录获取的令牌
const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6ImZvdW5kZXItMDAxIiwidXNlcm5hbWUiOiJmb3VuZGVyMSIsIm5hbWUiOiLlvKDliJvlp4vkuroiLCJyb2xlIjoiZm91bmRlciIsImRlcGFydG1lbnRfaWQiOiJkZXB0LTAwMSIsImlhdCI6MTc2NDc4MzkzOCwiZXhwIjoxNzY0ODcwMzM4fQ.ZHq2pgy-dadklIaCl5G2LiI6wTB8Ok8CUQlqNC7OCFU';

// 测试 personality-analysis 接口
function testPersonalityAnalysis() {
    const postData = JSON.stringify({
        logText: '今天完成了项目会议，讨论了新功能的设计方案'
    });

    const options = {
        hostname: 'localhost',
        port: 8080,
        path: '/api/ai/personality-analysis',
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(postData),
            'Authorization': `Bearer ${token}`
        }
    };

    console.log('测试 personality-analysis 接口...');
    const req = http.request(options, res => {
        let data = '';
        res.on('data', chunk => {
            data += chunk;
        });
        res.on('end', () => {
            console.log('personality-analysis 接口响应:', JSON.parse(data));
        });
    });

    req.on('error', error => {
        console.error('请求错误:', error);
    });

    req.write(postData);
    req.end();
}

// 测试 save-wordcloud 接口
function testSaveWordcloud() {
    const postData = JSON.stringify({
        analysisDate: new Date().toISOString(),
        keywords: [{word: '项目', weight: 0.8}, {word: '会议', weight: 0.6}],
        wordFrequencies: [{word: '项目', count: 2}, {word: '会议', count: 1}]
    });

    const options = {
        hostname: 'localhost',
        port: 8080,
        path: '/api/ai/save-wordcloud',
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(postData),
            'Authorization': `Bearer ${token}`
        }
    };

    console.log('测试 save-wordcloud 接口...');
    const req = http.request(options, res => {
        let data = '';
        res.on('data', chunk => {
            data += chunk;
        });
        res.on('end', () => {
            console.log('save-wordcloud 接口响应:', data);
        });
    });

    req.on('error', error => {
        console.error('请求错误:', error);
    });

    req.write(postData);
    req.end();
}

// 执行测试
testPersonalityAnalysis();
testSaveWordcloud();

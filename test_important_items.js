// 测试公司十大重要事项编辑功能
const API_BASE_URL = 'http://localhost:8080/api';

// 测试数据
const testImportantItem = {
    title: '测试重要事项',
    description: '这是一个测试重要事项的描述',
    priority: 'p1',
    deadline: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString() // 7天后
};

async function testImportantItemsAPI() {
    console.log('🚀 开始测试公司十大重要事项编辑功能...\n');
    
    try {
        // 1. 测试登录获取token
        console.log('1️⃣ 测试用户登录...');
        const loginResponse = await fetch(`${API_BASE_URL}/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                username: 'admin',
                password: 'admin123'
            })
        });
        
        if (!loginResponse.ok) {
            throw new Error('登录失败');
        }
        
        const loginData = await loginResponse.json();
        const token = loginData.token;
        console.log('✅ 登录成功，获得token');
        
        const headers = {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`
        };
        
        // 2. 测试创建重要事项
        console.log('\n2️⃣ 测试创建重要事项...');
        const createResponse = await fetch(`${API_BASE_URL}/company-important-items`, {
            method: 'POST',
            headers: headers,
            body: JSON.stringify(testImportantItem)
        });
        
        if (!createResponse.ok) {
            throw new Error('创建重要事项失败');
        }
        
        const createData = await createResponse.json();
        const itemId = createData.id;
        console.log('✅ 重要事项创建成功，ID:', itemId);
        
        // 3. 测试获取所有重要事项
        console.log('\n3️⃣ 测试获取所有重要事项...');
        const getAllResponse = await fetch(`${API_BASE_URL}/company-important-items/all`, {
            headers: headers
        });
        
        if (!getAllResponse.ok) {
            throw new Error('获取所有重要事项失败');
        }
        
        const allItems = await getAllResponse.json();
        console.log('✅ 获取所有重要事项成功，共', allItems.length, '个事项');
        
        // 4. 测试批量选择重要事项
        console.log('\n4️⃣ 测试批量选择重要事项...');
        const selectedIds = allItems.slice(0, Math.min(3, allItems.length)).map(item => item.id);
        
        const batchSelectResponse = await fetch(`${API_BASE_URL}/company-important-items/batch-select`, {
            method: 'PUT',
            headers: headers,
            body: JSON.stringify({ selectedIds: selectedIds })
        });
        
        if (!batchSelectResponse.ok) {
            throw new Error('批量选择重要事项失败');
        }
        
        const batchData = await batchSelectResponse.json();
        console.log('✅ 批量选择成功，选择了', batchData.selectedCount, '个事项');
        
        // 5. 测试获取已选择的重要事项
        console.log('\n5️⃣ 测试获取已选择的重要事项...');
        const getSelectedResponse = await fetch(`${API_BASE_URL}/company-important-items`, {
            headers: headers
        });
        
        if (!getSelectedResponse.ok) {
            throw new Error('获取已选择重要事项失败');
        }
        
        const selectedItems = await getSelectedResponse.json();
        console.log('✅ 获取已选择重要事项成功，共', selectedItems.length, '个事项');
        
        // 6. 测试更新重要事项
        console.log('\n6️⃣ 测试更新重要事项...');
        const updateData = {
            title: '更新后的测试重要事项',
            description: '这是更新后的描述',
            priority: 'p0',
            status: 'in_progress',
            deadline: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString()
        };
        
        const updateResponse = await fetch(`${API_BASE_URL}/company-important-items/${itemId}`, {
            method: 'PUT',
            headers: headers,
            body: JSON.stringify(updateData)
        });
        
        if (!updateResponse.ok) {
            throw new Error('更新重要事项失败');
        }
        
        console.log('✅ 重要事项更新成功');
        
        // 7. 测试删除重要事项
        console.log('\n7️⃣ 测试删除重要事项...');
        const deleteResponse = await fetch(`${API_BASE_URL}/company-important-items/${itemId}`, {
            method: 'DELETE',
            headers: headers
        });
        
        if (!deleteResponse.ok) {
            throw new Error('删除重要事项失败');
        }
        
        console.log('✅ 重要事项删除成功');
        
        console.log('\n🎉 所有测试通过！公司十大重要事项编辑功能正常工作。');
        
    } catch (error) {
        console.error('❌ 测试失败:', error.message);
        console.error('详细错误:', error);
    }
}

// 运行测试
testImportantItemsAPI();

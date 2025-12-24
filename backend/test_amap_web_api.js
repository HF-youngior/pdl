const axios = require('axios');
require('dotenv').config();

// 测试高德地图Web服务API
async function testAmapWebAPI() {
  const AMAP_API_KEY = process.env.AMAP_API_KEY;
  // 使用Web服务API的地理编码接口
  const AMAP_GEOCODE_URL = 'https://restapi.amap.com/v3/geocode/geo';
  
  // 测试地址：北京市朝阳区
  const testAddress = '北京市朝阳区';
  
  console.log('测试高德地图Web服务API...');
  console.log(`API Key: ${AMAP_API_KEY}`);
  console.log(`测试地址: ${testAddress}`);
  
  try {
    const response = await axios.get(AMAP_GEOCODE_URL, {
      params: {
        key: AMAP_API_KEY,
        address: testAddress,
        city: '北京'
      }
    });
    
    if (response.data.status === '1' && response.data.geocodes && response.data.geocodes.length > 0) {
      const geocode = response.data.geocodes[0];
      console.log('\n✅ API调用成功！');
      console.log('格式化地址:', geocode.formatted_address);
      console.log('位置:', geocode.location);
      console.log('详细信息:');
      console.log('- 省份:', geocode.province);
      console.log('- 城市:', geocode.city);
      console.log('- 区县:', geocode.district);
      console.log('- 街道:', geocode.township);
      console.log('- adcode:', geocode.adcode);
    } else {
      console.log('\n❌ API调用失败');
      console.log('错误信息:', response.data.info);
      console.log('错误代码:', response.data.infocode);
    }
  } catch (error) {
    console.error('\n❌ API调用异常:', error.message);
    if (error.response) {
      console.error('响应状态码:', error.response.status);
      console.error('响应数据:', error.response.data);
    }
  }
}

testAmapWebAPI();
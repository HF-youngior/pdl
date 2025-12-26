const axios = require('axios');
require('dotenv').config();

// 测试高德地图API
async function testAmapAPI() {
  const AMAP_API_KEY = process.env.AMAP_API_KEY;
  const AMAP_GEOCODE_URL = 'https://restapi.amap.com/v3/geocode/regeo';
  
  // 使用天安门广场的经纬度进行测试
  const testLatitude = 39.908823;
  const testLongitude = 116.397470;
  
  console.log('测试高德地图API...');
  console.log(`API Key: ${AMAP_API_KEY}`);
  console.log(`测试坐标: 纬度 ${testLatitude}, 经度 ${testLongitude}`);
  
  try {
    const response = await axios.get(AMAP_GEOCODE_URL, {
      params: {
        key: AMAP_API_KEY,
        location: `${testLongitude},${testLatitude}`, // 注意：高德API使用经度,纬度的顺序
        poitype: '',
        radius: 1000,
        extensions: 'all',
        batch: 'false',
        roadlevel: 0
      }
    });
    
    if (response.data.status === '1' && response.data.regeocode) {
      const addressComponent = response.data.regeocode.addressComponent;
      const formattedAddress = response.data.regeocode.formatted_address;
      
      console.log('\n✅ API调用成功！');
      console.log('格式化地址:', formattedAddress);
      console.log('详细信息:');
      console.log('- 国家:', addressComponent.country || '');
      console.log('- 省份:', addressComponent.province || '');
      console.log('- 城市:', addressComponent.city || addressComponent.district || '');
      console.log('- 区县:', addressComponent.district || '');
      console.log('- 乡镇:', addressComponent.township || '');
      console.log('- 街道:', addressComponent.streetNumber?.street || '');
      console.log('- 门牌号:', addressComponent.streetNumber?.number || '');
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

testAmapAPI();
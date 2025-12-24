const axios = require('axios');
require('dotenv').config();

// 高德地图API配置
const AMAP_API_KEY = process.env.AMAP_API_KEY;
const AMAP_GEOCODE_URL = 'https://restapi.amap.com/v3/geocode/regeo';

// 经纬度转中文地址函数
async function convertToAddress(latitude, longitude) {
  if (!latitude || !longitude) return null;
  
  try {
    const response = await axios.get(AMAP_GEOCODE_URL, {
      params: {
        key: AMAP_API_KEY,
        location: `${longitude},${latitude}`, // 注意：高德API使用经度,纬度的顺序
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
      
      // 构建详细地址信息
      const addressInfo = {
        formatted_address: formattedAddress,
        country: addressComponent.country || '',
        province: addressComponent.province || '',
        city: addressComponent.city || addressComponent.district || '',
        district: addressComponent.district || '',
        township: addressComponent.township || '',
        street: addressComponent.streetNumber?.street || '',
        street_number: addressComponent.streetNumber?.number || ''
      };
      
      return addressInfo;
    } else {
      console.warn('经纬度转地址失败:', response.data.info);
      return null;
    }
  } catch (error) {
    console.error('经纬度转地址异常:', error.message);
    return null;
  }
}

// 测试地址转换功能
async function testAddressConversion() {
  console.log('测试地址转换功能...\n');
  
  // 测试天安门广场的经纬度
  const testLatitude = 39.908823;
  const testLongitude = 116.397470;
  
  console.log(`测试坐标: 纬度 ${testLatitude}, 经度 ${testLongitude}`);
  const addressInfo = await convertToAddress(testLatitude, testLongitude);
  
  if (addressInfo) {
    console.log('转换成功!');
    console.log('格式化地址:', addressInfo.formatted_address);
    console.log('省份:', addressInfo.province);
    console.log('城市:', addressInfo.city);
    console.log('区县:', addressInfo.district);
    console.log('街道:', addressInfo.township);
  } else {
    console.log('转换失败!');
  }
  
  console.log('\n');
  
  // 测试上海外滩的经纬度
  const shanghaiLatitude = 31.239663;
  const shanghaiLongitude = 121.499809;
  
  console.log(`测试坐标: 纬度 ${shanghaiLatitude}, 经度 ${shanghaiLongitude}`);
  const shanghaiAddressInfo = await convertToAddress(shanghaiLatitude, shanghaiLongitude);
  
  if (shanghaiAddressInfo) {
    console.log('转换成功!');
    console.log('格式化地址:', shanghaiAddressInfo.formatted_address);
    console.log('省份:', shanghaiAddressInfo.province);
    console.log('城市:', shanghaiAddressInfo.city);
    console.log('区县:', shanghaiAddressInfo.district);
    console.log('街道:', shanghaiAddressInfo.township);
  } else {
    console.log('转换失败!');
  }
}

testAddressConversion();
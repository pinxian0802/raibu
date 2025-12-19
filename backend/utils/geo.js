/**
 * PostGIS 空間查詢工具函數
 */

/**
 * 建立 PostGIS Point SQL 片段
 * @param {number} lng - 經度
 * @param {number} lat - 緯度
 * @returns {string} SQL 片段
 */
function makePointSQL(lng, lat) {
  return `ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)`;
}

/**
 * 建立查詢範圍的 Envelope SQL
 * @param {number} minLng 
 * @param {number} minLat 
 * @param {number} maxLng 
 * @param {number} maxLat 
 * @returns {string} SQL 片段
 */
function makeEnvelopeSQL(minLng, minLat, maxLng, maxLat) {
  return `ST_MakeEnvelope(${minLng}, ${minLat}, ${maxLng}, ${maxLat}, 4326)`;
}

/**
 * 建立 ST_Within 查詢條件
 * @param {string} column - 欄位名稱
 * @param {number} minLng 
 * @param {number} minLat 
 * @param {number} maxLng 
 * @param {number} maxLat 
 * @returns {string} SQL 條件
 */
function withinEnvelopeSQL(column, minLng, minLat, maxLng, maxLat) {
  return `ST_Within(${column}, ${makeEnvelopeSQL(minLng, minLat, maxLng, maxLat)})`;
}

/**
 * 計算兩點距離的 SQL
 * @param {string} column1 - 第一個座標欄位
 * @param {string} column2OrPoint - 第二個座標欄位或 Point SQL
 * @returns {string} SQL 片段 (回傳公尺)
 */
function distanceSQL(column1, column2OrPoint) {
  return `ST_Distance(${column1}::geography, ${column2OrPoint}::geography)`;
}

/**
 * 從 PostGIS Point 提取經度
 * @param {string} column 
 * @returns {string} SQL 片段
 */
function extractLngSQL(column) {
  return `ST_X(${column})`;
}

/**
 * 從 PostGIS Point 提取緯度
 * @param {string} column 
 * @returns {string} SQL 片段
 */
function extractLatSQL(column) {
  return `ST_Y(${column})`;
}

/**
 * 驗證座標是否有效
 * @param {number} lat - 緯度 (-90 ~ 90)
 * @param {number} lng - 經度 (-180 ~ 180)
 * @returns {boolean}
 */
function isValidCoordinate(lat, lng) {
  return (
    typeof lat === 'number' &&
    typeof lng === 'number' &&
    lat >= -90 && lat <= 90 &&
    lng >= -180 && lng <= 180
  );
}

/**
 * 判斷座標是否在指定範圍內（含容許誤差）
 * 用於 Geo-fencing 判定
 * @param {object} point - { lat, lng }
 * @param {object} center - { lat, lng }
 * @param {number} radiusMeters - 範圍半徑（公尺）
 * @param {number} toleranceMeters - 容許誤差（公尺），預設 30
 * @returns {boolean}
 */
function isWithinRadius(point, center, radiusMeters, toleranceMeters = 30) {
  // 使用 Haversine 公式計算距離
  const R = 6371000; // 地球半徑（公尺）
  const dLat = toRad(point.lat - center.lat);
  const dLng = toRad(point.lng - center.lng);
  const a = 
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(center.lat)) * Math.cos(toRad(point.lat)) *
    Math.sin(dLng / 2) * Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const distance = R * c;
  
  return distance <= (radiusMeters + toleranceMeters);
}

function toRad(deg) {
  return deg * (Math.PI / 180);
}

module.exports = {
  makePointSQL,
  makeEnvelopeSQL,
  withinEnvelopeSQL,
  distanceSQL,
  extractLngSQL,
  extractLatSQL,
  isValidCoordinate,
  isWithinRadius,
};

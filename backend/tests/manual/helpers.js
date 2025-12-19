const BASE_URL = 'http://localhost:3000/api/v1';

async function request(path, options = {}) {
  const url = `${BASE_URL}${path}`;
  const response = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...options.headers,
    },
  });
  
  const data = await response.json();
  if (!response.ok) {
    console.error(`❌ ${options.method || 'GET'} ${path} failed:`, data);
  }
  return { status: response.status, data };
}

module.exports = {
  BASE_URL,
  request,
};

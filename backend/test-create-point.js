const fs = require("fs");
const path = require("path");
const FormData = require("form-data");
const fetch = require("node-fetch");

const BASE_URL = "http://localhost:3000";
const TEST_POINT_ID = "f5574333-c4d1-4477-b9b7-88c1672005b2"; // 你剛建立成功的 point ID
const TEST_USER_ID = "bd20af78-fb94-430b-9ea4-3f4aa6b3808c";  // 你 Supabase 建立的 user

async function uploadImage() {
  try {
    console.log("📤 Uploading test image...\n");

    // 1. 使用真正的圖片
    const filePath = path.join(__dirname, "ajiao.png");

    if (!fs.existsSync(filePath)) {
      console.error("❌ Error: 圖片檔案不存在！請確認 ajiao.png 在 backend/ 目錄下");
      return;
    }

    const fileStream = fs.createReadStream(filePath);

    // 2. 使用 Node.js form-data 套件
    const form = new FormData();
    form.append("image_file", fileStream, "ajiao.png");
    form.append("uploader_id", TEST_USER_ID);
    form.append("latitude", "25.0330");
    form.append("longitude", "121.5654");

    // 3. 發送 multipart/form-data 請求
    const res = await fetch(`${BASE_URL}/points/${TEST_POINT_ID}/images`, {
      method: "POST",
      body: form,
      headers: form.getHeaders(), // ⬅️ 這個非常重要，multer 才能解析
    });

    const data = await res.json();

    console.log("📄 API Response:\n", data);

  } catch (err) {
    console.error("❌ Upload Failed:", err);
  }
}

uploadImage();

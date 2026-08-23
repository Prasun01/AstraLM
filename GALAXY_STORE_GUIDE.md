# Samsung Galaxy Store Publishing Guide for AstraLM

The **Samsung Galaxy Store** (Samsung Developer Seller Portal) is **100% free** to register and publish Android apps (no registration fees).

---

### 1. 🌐 Create Your Free Samsung Developer Account
1. Go to the [Samsung Galaxy Store Seller Portal](https://seller.samsungapps.com).
2. Sign in with your Samsung Account (or create one for free).
3. Complete the free developer registration (select **Individual Developer** or **Company**).

---

### 2. 📦 Binary Files to Upload
Samsung Galaxy Store accepts either **signed APK** or **signed AAB**:
- **Signed Release APK:** `build/app/outputs/flutter-apk/app-release.apk` *(Recommended)*
- **Signed Release AAB:** `build/app/outputs/bundle/release/app-release.aab`
- Both files are signed with your production keystore (`android/privatelm-release.jks`).

---

### 3. 📝 App Information for Galaxy Store Listing

| Field | Value |
| :--- | :--- |
| **Application Title** | `AstraLM - Private On-Device AI` |
| **Default Language** | English (US) |
| **Category** | Applications > Utilities / Productivity |
| **Age Rating** | 4+ / Everyone (or 12+ general utility) |
| **Price** | Free |
| **Supported Devices** | All Samsung Galaxy Phones & Tablets (Android 9.0+ / API 28 to API 36) |

---

### 4. 📄 Descriptions (Copy & Paste)

#### **Short Description**
```
Run AI models 100% locally on your Galaxy device. Private, offline, fast, and secure.
```

#### **Detailed Description**
```
AstraLM brings the true power of private artificial intelligence directly to your Samsung Galaxy device. Run open-source Large Language Models (LLMs) and Vision models 100% locally on your hardware with zero data leaving your phone.

🔒 100% PRIVATE & OFFLINE
• No account required, no tracking, no subscriptions.
• All text generation, document analysis, and image understanding occur directly on your device CPU and GPU.
• Complete peace of mind: your conversations, files, and photos remain entirely yours.

⚡ OPTIMIZED FOR SAMSUNG HARDWARE
• Mali & Adreno GPU Acceleration via LiteRT OpenCL.
• llama.cpp Engine: Optimized quantized models (Llama 3, Qwen 2.5, Gemma, Mistral, Phi-3, DeepSeek).
• Multimodal Vision: Analyze photos, receipts, and documents locally.

✨ MODERN GALAXY EXPERIENCE
• Fluid UI with 120Hz smooth scrolling and dark/light themes.
• Voice & Audio input.
• Fast attachments: Photo library, Camera capture, and Document files.

Download AstraLM and enjoy sovereign, private, on-device AI.
```

---

### 5. 🖼️ Visual Assets Needed

1. **App Icon:**
   - 512 × 512 PNG (32-bit with alpha).
2. **Cover Image / Feature Graphic:**
   - Use `store_assets/feature_graphic.jpg` (1024 × 500 or 16:9).
3. **Screenshots:**
   - Minimum 4 screenshots (Portrait format, 1080 × 1920 or higher).
   - Capture directly from your Samsung Galaxy A35.

---

### 6. 🚀 Submission Checklist
1. Click **Add Application** in the Seller Portal.
2. Select **Android** and enter Application Title: `AstraLM - Private On-Device AI`.
3. Upload `app-release.apk` (or `app-release.aab`).
4. Fill in the App Details, Category, and Descriptions from above.
5. Upload Icon, Feature Graphic, and Screenshots.
6. Link Privacy Policy URL (e.g. from GitHub or website using `PRIVACY_POLICY.md`).
7. Click **Submit** for review (approval usually takes 1–3 business days).

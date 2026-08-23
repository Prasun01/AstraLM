# Privacy Policy for AstraLM

**Effective Date:** August 24, 2026  
**Last Updated:** August 24, 2026  

AstraLM ("we", "our", or "the App") is developed with privacy as a foundational principle. AstraLM is an on-device, private AI client designed to run large language and multimodal models locally on your Android device.

---

### 1. Zero Personal Data Collection
- **100% On-Device Processing**: When operating in Local Inference mode, all text prompts, images, documents, and chat history are processed strictly on your device's hardware (CPU/GPU/NPU).
- **No Telemetry / No Tracking**: We do not collect, log, track, or share your prompts, generated responses, uploaded photos, documents, or personal identifiers.
- **No Third-Party Analytics**: We do not sell, rent, or monetize any user data.

---

### 2. Permissions & Usage
AstraLM requests only permissions strictly necessary for user-initiated core features:
- **Camera (`android.permission.CAMERA`)**: Used solely when you choose to take a photo directly within the app to attach to a multimodal chat session. Photos remain local on your device.
- **Microphone (`android.permission.RECORD_AUDIO`)**: Used strictly for real-time speech-to-text input when you tap the voice button. Audio data is transcribed on-device and is never transmitted to external servers.
- **Storage / Photos / Files**: Used solely to allow you to import GGUF / LiteRT model files and select photo or document attachments.
- **Foreground Service & Wake Lock**: Used exclusively to maintain uninterrupted model generation or long model downloads in the background when requested by the user.

---

### 3. Optional Cloud Mode
If you explicitly choose to switch to Cloud Mode and configure third-party API providers (e.g. OpenAI, Anthropic, Gemini, Groq, OpenRouter, Stability AI):
- Your queries and API requests are sent directly from your device to your chosen provider using encrypted HTTPS/TLS connections.
- We do not operate intermediary proxy servers that inspect or store your cloud traffic.
- Your API keys are stored securely on your local device.

---

### 4. Data Retention & Deletion
- All conversation histories, models, and custom settings are stored locally in your device's private sandboxed app directory.
- You can delete any conversation, clear the app cache, or remove downloaded models at any time within the app's settings, or by clearing the app data in Android system settings.

---

### 5. Contact Us
If you have any questions or feedback regarding this Privacy Policy, please contact:
- **Developer / Support Email:** systemerror505@proton.me

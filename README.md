# AstraLM — On-Device & Hybrid AI Assistant

![AstraLM Feature Banner](store_assets/feature_graphic.jpg)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://android.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)
[![Latest Release](https://img.shields.io/badge/Release-v1.0.6-blue?style=for-the-badge)](https://github.com/Prasun01/AstraLM/releases/tag/v1.0.6)

**AstraLM** is an open-source, high-performance AI assistant for Android. Built with Flutter and native C++ inference engines, AstraLM is designed around an **on-device first, hybrid-capable architecture** — giving you the flexibility to run private quantized LLMs directly on your phone's hardware, or connect your own API keys for cloud-based reasoning and image generation.

---

## ⚡ Key Highlights

- 📱 **On-Device Local Inference (Offline)**
  - Runs quantized GGUF models directly on device CPU/GPU via `llama.cpp`.
  - Supports Google LiteRT-LM for accelerated mobile models.
  - When using local models, all inference is computed 100% locally with zero internet connection required.
- ☁️ **Optional Cloud Mode (Bring-Your-Own-Key)**
  - Seamlessly switch to frontier models (OpenAI, Anthropic Claude, Google Gemini, DeepSeek, Groq, OpenRouter).
  - Native Image Generation via Stability AI (SD3.5 Turbo, Ultra) & OpenAI DALL-E 3.
  - API keys are stored locally on your device in encrypted sandbox storage with zero third-party telemetry or middleware servers.
- 📄 **Interactive Fullscreen Canvas**
  - Live side-by-side or fullscreen workspace for code, markdown documents, and HTML previews.
  - 0ms touch latency with hardware-accelerated gesture recognizers.
- 🔄 **In-App Auto Updates & Remote Config**
  - Integrated background updater that checks GitHub Releases for one-tap seamless upgrades.
  - Dynamic configuration for memory alerts and thinking status messages.
- 🎨 **Minimalist & Ergonomic UI**
  - Instant zero-lag launch directly into chat.
  - Smooth 120Hz scrolling, dynamic reasoning status cross-fades, and borderless space-gray dark/light themes.

---

## 🏗️ Architecture & Privacy Model

```
┌─────────────────────────────────────────────────────────────┐
│                     AstraLM Flutter UI                      │
│      Chat Workspace · Fullscreen Canvas · Model Manager     │
└──────────────────────────────┬──────────────────────────────┘
                               │
               ┌───────────────┴───────────────┐
               ▼                               ▼
    ┌──────────────────────┐        ┌──────────────────────┐
    │  Local AI Runtimes   │        │   Cloud AI Engine    │
    │  (100% On-Device)    │        │  (Direct Client-API) │
    ├──────────────────────┤        ├──────────────────────┤
    │ • GGUF (llama.cpp)   │        │ • Anthropic Claude   │
    │ • LiteRT-LM (OpenCL) │        │ • OpenAI & DALL-E 3  │
    │ • Offline Voice STT  │        │ • Google Gemini      │
    │ • Local Vision (VLM) │        │ • Stability AI SD3.5 │
    └──────────────────────┘        └──────────────────────┘
               │                               │
               ▼                               ▼
     On-Device Hardware             Direct Encrypted HTTPS
     (No Data Outbound)             (Your Keys, Direct API)
```

### Privacy & Transparency
- **Local Mode:** When running local GGUF/LiteRT models, inference is performed strictly offline on your phone’s processor. No conversation history, prompts, or images are transmitted.
- **Cloud Mode:** When you explicitly enable Cloud Mode, queries are transmitted directly over encrypted TLS (HTTPS) to the respective model provider (e.g. OpenAI or Anthropic) using your personal API key. AstraLM does not run any proxy servers, data collection, or telemetry analytics.

---

## 📥 Download & Installation

Get the latest signed APK directly from the [GitHub Releases](https://github.com/Prasun01/AstraLM/releases) page:

1. Download **[`AstraLM-v1.0.6.apk`](https://github.com/Prasun01/AstraLM/releases/download/v1.0.6/AstraLM-v1.0.6.apk)**.
2. Install the APK on your Android device (Android 10+ / API 29+ recommended, ARM64).
3. Open AstraLM, download a recommended local model (e.g. Llama 3.2 1B or Qwen 2.5 1.5B), or paste your API keys in Settings.

---

## 🛠️ Developer Setup & Building

### Prerequisites
- Flutter SDK `>=3.3.0`
- Android SDK (API 28+) & NDK
- Java JDK 17 or 21

### Build Steps
```bash
# Clone the repository
git clone https://github.com/Prasun01/AstraLM.git
cd AstraLM

# Fetch dependencies
flutter pub get

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release
```

---

## 🙏 Credits & Acknowledgments

- Built upon and inspired by the original **[PrivateLM](https://github.com/orailnoor/cross-platform-llm-client)** by [@orailnoor](https://github.com/orailnoor).
- Powered by [llama.cpp](https://github.com/ggerganov/llama.cpp) by Georgi Gerganov and [Google LiteRT](https://ai.google.dev/edge/litert).

---

## 📄 License

Distributed under the **MIT License**. See [`LICENSE`](./LICENSE) for more information.

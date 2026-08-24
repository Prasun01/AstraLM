# AstraLM — Release Notes & Changelog

## 🚀 Version Overview
This release delivers a comprehensive architectural overhaul, strict monochrome styling, a complete icon system migration to **Phosphor Bold**, zero-lag Canvas Workspace, live unbuffered online model streaming, robust multi-model memory management, and Samsung Galaxy Mali/Exynos GPU hardware stabilization.

---

## ✨ Key Features & Improvements

### 1. 🎨 Design & UI Modernization
- **Strict Monochrome Palette**: Standardized pure black (`#000000`), neutral dark greys (`#101010`, `#141416`, `#181818`), and crisp white typography across all screens.
- **Borderless Modern Aesthetics**: Removed all grey borders, harsh card outlines, and legacy dividers across Settings, Popovers, and Dialogs.
- **Phosphor Bold Icon System**: Replaced all Material icons with genuine [Phosphor Bold](https://phosphoricons.com/) icons (`PhosphorIconsBold.*`).
- **Smooth Gradient Fade Transitions**:
  - Expanded conversation drawer session list fade seamlessly above the Settings footer button.
  - Enhanced bottom chat gradient fade (`64px`) behind the floating action bar.

### 2. ⚡ Live Unbuffered Online Model Streaming
- **Zero-Latency Real-Time SSE Streaming**: Replaced buffered HTTP calls with unbuffered `dart:io HttpClient` socket streams (`Cache-Control: no-cache`).
- **Google Gemini Streaming**: Integrated native `streamGenerateContent?alt=sse` for real-time word-by-word streaming.
- **Anthropic Claude & DeepSeek-R1 Support**: Added native SSE delta streaming and real-time reasoning token (`reasoning_content`) visibility.
- **Smooth Word-by-Word Fallback**: Any batch endpoint smoothly renders with adaptive progressive word streaming and soft `AnimatedOpacity` fade-in.

### 3. 🛡️ Single-Session Incognito Mode
- **Zero-Persistence Privacy**: Messages in Incognito mode are never saved to Hive or disk.
- **Auto-Deletion Lifecycle**: Incognito is strictly confined to the active chat session. Toggling off, closing the chat, tapping New Chat (`+`), or switching conversations automatically destroys all private messages from memory.

### 4. 🧠 Memory & Inference Engine Optimization
- **Sequential Local Model Switching**: Selecting a new local model or cloud provider proactively triggers a full `unloadModel()` and GPU/VRAM memory flush before instantiating the new engine.
- **Samsung Galaxy / Mali GPU Protection**:
  - Added dynamic context size clamping (`1536–2048` tokens) for Gemma / LiteRT models on Mali-G68 / Exynos SoCs.
  - Implemented automatic **CPU Safe Fallback** in `InferenceAndroidService` if GPU OpenCL compilation runs out of memory on Mali.
- **Vision Model Fixes**:
  - Fixed Qwen2-VL-2B catalog validation threshold preventing false "Incomplete Model File" errors.

### 5. 📝 Canvas Workspace 2.0
- **Instantaneous Tab Switching**: Replaced `TabBarView` with `IndexedStack` to keep `InAppWebView` live in memory with **0ms lag**.
- **Accurate Code Extraction**: When opening "Open in Canvas", extraneous AI conversational preamble is cleanly stripped, extracting only the clean markdown/code.
- **Clean Borderless Floating Cards**: Polished document styling, syntax highlighting, and action bars.

---

## 🛠️ Summary of Changed Files

| File | Changes |
|---|---|
| [`lib/views/chat_view.dart`](file:///home/prasun/AstraLM/lib/views/chat_view.dart) | Phosphor icons, Settings drawer footer, expanded gradient fades, quick model switcher |
| [`lib/views/settings_view.dart`](file:///home/prasun/AstraLM/lib/views/settings_view.dart) | Nested sub-settings, strict monochrome design language, zero grey borders |
| [`lib/services/cloud_service.dart`](file:///home/prasun/AstraLM/lib/services/cloud_service.dart) | Unbuffered `HttpClient` SSE streaming for Gemini, Claude, OpenAI, DeepSeek, Kimi |
| [`lib/services/device_info_service.dart`](file:///home/prasun/AstraLM/lib/services/device_info_service.dart) | Mali/Exynos calibration and safe context limits for Gemma models |
| [`lib/services/inference_android.dart`](file:///home/prasun/AstraLM/lib/services/inference_android.dart) | LiteRT GPU failure recovery & CPU safe mode fallback |
| [`lib/controllers/chat_controller.dart`](file:///home/prasun/AstraLM/lib/controllers/chat_controller.dart) | Single-session incognito lifecycle, stop-generation state, progressive stream animation |
| [`lib/controllers/model_controller.dart`](file:///home/prasun/AstraLM/lib/controllers/model_controller.dart) | Eager model unloading, robust GGUF validation, solid 100% opaque notifications |
| [`lib/widgets/canvas_workspace.dart`](file:///home/prasun/AstraLM/lib/widgets/canvas_workspace.dart) | 0ms lag `IndexedStack` tab switcher, Phosphor icons, document view |
| [`lib/core/icons.dart`](file:///home/prasun/AstraLM/lib/core/icons.dart) | Centralized Phosphor Bold icon registry |
| [`lib/core/constants.dart`](file:///home/prasun/AstraLM/lib/core/constants.dart) | Updated Qwen2-VL-2B metadata & cloud endpoints |

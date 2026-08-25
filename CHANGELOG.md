# AstraLM Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.7] - 2026-08-25

### Added
- **Redesigned Welcome Walkthrough**: Implemented an obsidian-themed 3-step onboarding flow with borderless elements, fluid page transitions, and structured initial paths:
  - Step 1: On-device private inference overview.
  - Step 2: Universal cloud ecosystem and client-side encryption.
  - Step 3: Getting started actions (Download starter local model or connect cloud API key).
- **Smart Online Model Filtering**: Intelligent filtering across cloud provider endpoints (Google Gemini, OpenAI, DeepSeek, OpenRouter, NVIDIA NIM):
  - Filters out embedding models, speech/audio endpoints (TTS, Whisper), moderation endpoints, and legacy completion models.
  - Prioritizes top chat, reasoning, and multimodal models (DeepSeek-R1, Gemini 2.5 Pro/Flash, Claude 3.5 Sonnet, GPT-4o).
- **Online Models FAQ & Setup Documentation**: Added an expandable accordion guide inside the Online Models view explaining API keys, recommended providers, privacy guarantees, and custom server configuration.
- **Monochrome Provider Logos**: Added custom monochrome vector assets for OpenRouter, OpenAI, DeepSeek, Google Gemini, Anthropic, NVIDIA NIM, Groq, and Stability AI.
- **Android-Optimized Local Models**: Added verified low-memory local models to the catalog (Llama-3.2-1B LiteRT-LM, SmolLM2-360M, SmolLM2-1.7B, Ministral-3B, Qwen2.5-0.5B, DeepSeek-R1-Distill-Qwen-1.5B).
- **Background Download Notifications**: Configured Android DownloadManager with completed visibility and a dedicated notification channel (`astralm_model_downloads`).

### Changed
- **Local Model Filter Bar**: Migrated to a single-row horizontal scrolling chip layout with smooth left and right fading edge masks.
- **Filter Registry Update**: Fixed category routing and item count calculations for LiteRT, GGUF, and Reasoning models in `ModelController`.
- **UI Element Cleanup**: Removed grey outlines and unnecessary icon clutter across buttons and filter pills.

---

## [1.0.6] - 2026-08-25

### Added
- **Phosphor Bold Icon Migration**: Replaced Material icons across all views with Phosphor Bold iconography.
- **Real-Time Unbuffered SSE Streaming**: Integrated unbuffered socket streaming (`HttpClient`) for Google Gemini (`streamGenerateContent?alt=sse`), Claude, OpenAI, and DeepSeek-R1.
- **Single-Session Incognito Mode**: Ephemeral conversation state with automatic in-memory destruction upon session switch or completion.
- **Canvas Workspace 2.0**: Zero-latency tab switching using `IndexedStack` and automated code/markdown block extraction.

### Fixed
- **Sequential Model Switching**: Added eager unloading and memory purging to prevent dual-model VRAM collisions during model transitions.
- **Hardware Compatibility**: Implemented Mali-G68 and Exynos context clamping and automatic CPU safe fallback upon OpenCL compilation faults.

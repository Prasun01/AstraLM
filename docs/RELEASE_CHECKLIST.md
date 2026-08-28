# AstraLM Release & Quality Assurance Checklist

This document defines the repeatable test checklist for every AstraLM release.

---

## 1. Model Download & Network Resilience (P0)

* [ ] **Fresh Multi-GB Download Test:**
  * Download a large model (e.g., Kimi Moonlight 16B IQ2_XXS, 5.50 GB).
  * Confirm download starts immediately with 4 parallel chunk streams.
  * Verify throughput exceeds 10–30 MB/s on unthrottled broadband.
* [ ] **Network Interruption & Resumption Test:**
  * Toggle Airplane Mode mid-download (at ~30% progress).
  * Confirm the download pauses cleanly without crashing or corrupting `.part`.
  * Reconnect to Wi-Fi and verify the download resumes from the exact saved byte offset.
* [ ] **App Kill & Cold Restart Test:**
  * Force close AstraLM from the Android Recents menu during an active download.
  * Reopen AstraLM. Confirm the download is detected from `.part.meta` and resumes without re-downloading existing chunks.
* [ ] **File Integrity & Magic Header Verification:**
  * Verify the final file is checked for the ASCII `GGUF` magic header (`0x47 0x47 0x55 0x46`) before being marked ready.
  * Verify that truncated or server error responses (HTML/JSON) are rejected with clear error guidance.

---

## 2. Background Execution & OEM Power Management (P1)

* [ ] **Screen Off / App Backgrounding Test:**
  * Start a download and lock the device screen for 5 minutes.
  * Unlock the device; verify the download completed or continued at full speed with active `WifiLock` and `WakeLock`.
* [ ] **Status Bar Notification Test:**
  * Verify the live persistent notification displays percentage, speed (MB/s), and estimated time remaining (ETA).
  * Verify the completion notification appears when finished.
* [ ] **OEM Device Matrix:**
  * **Xiaomi / Redmi (HyperOS / MIUI):** Verified unthrottled socket throughput.
  * **Samsung (OneUI 6 / 7):** Verified background execution with battery optimization exemption.
  * **Tecno / Infinix (HiOS / XOS):** Verified no background freeze.

---

## 3. UI Performance & Model Browser (P1)

* [ ] **Zero-Flicker Scrolling:**
  * Scroll continuously through the AI Models catalog.
  * Verify 60/120 FPS fluid motion with no layout jitter, card rebuild flickering, or off-screen GPU stutter.
* [ ] **Dynamic OTA Catalog Sync:**
  * Verify that opening the app silently queries `models.json` on GitHub and caches updates in Hive.

---

## 4. On-Device Inference & Memory Safety (P2)

* [ ] **Model Loading & Memory Guard:**
  * Load a model matching the device's RAM tier.
  * Verify RAM check prevents loading models exceeding available memory.
* [ ] **Stop Generation & Cancellation:**
  * Tap "Stop" during token generation; verify inference halts immediately and frees worker locks.

---

## 5. Clean Release Build Verification

* [ ] `flutter analyze --no-fatal-infos` passes with 0 errors.
* [ ] Version code incremented in `pubspec.yaml`.
* [ ] Release APK compiled with `flutter build apk --release`.
* [ ] Emoji-free, clean changelog published to GitHub Releases.

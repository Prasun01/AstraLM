class AppConstants {
  AppConstants._();

  // Hive Box Names
  static const String chatSessionsBox = 'chat_sessions';
  static const String chatMessagesBox = 'chat_messages';
  static const String tasksBox = 'tasks';
  static const String settingsBox = 'settings';

  // Settings Keys
  static const String keyInferenceMode = 'inference_mode'; // 'local' or 'cloud'
  static const String keyCloudProvider =
      'cloud_provider'; // 'openai', 'anthropic', 'google', 'kimi'
  static const String keyOpenaiKey = 'openai_api_key';
  static const String keyAnthropicKey = 'anthropic_api_key';
  static const String keyGoogleKey = 'google_api_key';
  static const String keyKimiKey = 'kimi_api_key';
  static const String keyStabilityKey = 'stability_api_key';
  static const String keyNvidiaKey = 'nvidia_api_key';
  static const String keyGroqKey = 'groq_api_key';
  static const String keyOpenRouterKey = 'openrouter_api_key';
  static const String keyDeepSeekKey = 'deepseek_api_key';
  static const String keyCustomCloudName = 'custom_cloud_name';
  static const String keyCustomCloudBaseUrl = 'custom_cloud_base_url';
  static const String keyCustomCloudKey = 'custom_cloud_api_key';
  static const String keyCustomCloudProfiles = 'custom_cloud_profiles';
  static const String keyCustomCloudProfileIndex = 'custom_cloud_profile_index';
  static const String keyOpenaiModel = 'openai_model';
  static const String keyAnthropicModel = 'anthropic_model';
  static const String keyGoogleModel = 'google_model';
  static const String keyKimiModel = 'kimi_model';
  static const String keyStabilityModel = 'stability_model';
  static const String keyNvidiaModel = 'nvidia_model';
  static const String keyGroqModel = 'groq_model';
  static const String keyOpenRouterModel = 'openrouter_model';
  static const String keyDeepSeekModel = 'deepseek_model';
  static const String keyCustomCloudModel = 'custom_cloud_model';
  static const String keyGlobalSystemPrompt = 'global_system_prompt';
  static const String keyLocalModelPath = 'local_model_path';
  static const String keyLocalModelName = 'local_model_name';
  static const String keyLocalModelRuntime = 'local_model_runtime';
  static const String keyLocalModelBackend = 'local_model_backend';
  static const String keyLiteRtPerformanceMode = 'litert_performance_mode';
  static const String keyLiteRtGpuWarningAccepted =
      'litert_gpu_warning_accepted';
  static const String keyLiteRtGpuLoadPending = 'litert_gpu_load_pending';
  static const String keyLiteRtGpuCrashDetected = 'litert_gpu_crash_detected';
  static const String keyImageModelPath = 'image_model_path';
  static const String keyImageModelName = 'image_model_name';
  static const String keyTemperature = 'temperature';
  static const String keyMaxTokens = 'max_tokens';
  static const String keyContextSize = 'context_size';
  static const String keyServerApiKey = 'server_api_key';
  static const String keyServerUseApiKey = 'server_use_api_key';
  static const String keyImageSteps = 'image_steps';
  static const String keyImageGenForceCpu = 'image_gen_force_cpu';
  static const String keyImageGenBackend = 'image_gen_backend';
  static const String keyImageGenGpuGuardMb = 'image_gen_gpu_guard_mb';
  static const String keyImageGenSize = 'image_gen_size';
  static const String keyImageGenQuantization = 'image_gen_quantization';
  static const String keyFontScale = 'font_scale';
  static const String keyHasSeenWelcomeGuide = 'has_seen_welcome_guide';

  // Default Model Config
  static const double defaultTemperature = 0.7;
  static const int defaultMaxTokens = 1024;
  static const int defaultContextSize = 2048;
  static const String defaultLiteRtPerformanceMode = 'auto_fast';
  static const int defaultImageSteps = 1;
  static const bool defaultImageGenForceCpu = true;
  static const int defaultImageGenGpuGuardMb = 1843; // 1.8 GB
  static const int defaultImageGenSize = 0; // 0 = Auto recommended
  static const double defaultFontScale = 1.0; // Recommended default size

  // System Prompt (compact for small context models)
  static const String systemPrompt =
      '''You are AI Chat, a helpful and friendly assistant. Be concise, accurate, and conversational. Answer questions directly without unnecessary preamble.''';

  // System Prompt for Uncensored Models
  static const String uncensoredSystemPrompt =
      '''You are AI Chat running with an uncensored local model. Be direct, mature, and conversational. Avoid moralizing or unnecessary disclaimers, but keep answers accurate and do not help with real-world harm, abuse, or illegal activity.''';

  static bool isUncensoredModelName(String value) {
    final lower = value.toLowerCase();
    return lower.contains('uncensored') ||
        lower.contains('abliterated') ||
        lower.contains('unrestricted') ||
        lower.contains('dolphin');
  }

  // Available Models for Download
  static const List<Map<String, String>> availableModels = [
    {
      'name': 'Qwen 2.5 0.5B Instruct (LiteRT-LM)',
      'filename': 'Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv4096.litertlm',
      'url':
          'https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct/resolve/main/Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv4096.litertlm',
      'size': '586 MB',
      'description':
          'Ultra-lightweight Qwen 2.5 model optimized with LiteRT int8 quantization for ultra-fast response on low-RAM devices',
      'template': 'litert',
      'runtime': 'litert',
      'quantization': 'int8',
      'ram_required': '1.2 GB',
      'tags': 'general,fast,tiny,qwen,litert',
    },
    {
      'name': 'Qwen2.5-0.5B Instruct (Q4_K_M)',
      'filename': 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
      'url':
          'https://huggingface.co/bartowski/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf',
      'size': '398 MB',
      'description':
          'Instant response ultra-compact 0.5B GGUF model for older devices and maximum speed',
      'template': 'chatml',
      'runtime': 'llama',
      'quantization': 'Q4_K_M',
      'ram_required': '1.0 GB',
      'tags': 'general,fast,tiny,qwen,gguf',
    },
    {
      'name': 'Qwen 2.5 1.5B Instruct (LiteRT-LM)',
      'filename': 'Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.litertlm',
      'url':
          'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.litertlm',
      'size': '1.49 GB',
      'description':
          'Balanced LiteRT-LM chat model with int8 quantization; excellent reasoning and instruction following',
      'template': 'litert',
      'runtime': 'litert',
      'quantization': 'int8',
      'ram_required': '2.5 GB',
      'tags': 'general,balanced,coding,qwen,litert',
    },
    {
      'name': 'Qwen2.5-1.5B Instruct (Q4_K_M)',
      'filename': 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
      'url':
          'https://huggingface.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf',
      'size': '986 MB',
      'description':
          'Highly capable 1.5B parameter GGUF model offering stellar text generation and coding capability',
      'template': 'chatml',
      'runtime': 'llama',
      'quantization': 'Q4_K_M',
      'ram_required': '2.0 GB',
      'tags': 'general,balanced,coding,qwen,gguf',
    },
    {
      'name': 'Qwen 2.5 3B Instruct (LiteRT-LM)',
      'filename': 'Qwen2.5-3B-Instruct_multi-prefill-seq_q8_ekv4096.litertlm',
      'url':
          'https://huggingface.co/litert-community/Qwen2.5-3B-Instruct/resolve/main/Qwen2.5-3B-Instruct_multi-prefill-seq_q8_ekv4096.litertlm',
      'size': '3.05 GB',
      'description':
          'High intelligence 3B LiteRT-LM model with GPU acceleration support for mid-to-high tier mobile devices',
      'template': 'litert',
      'runtime': 'litert',
      'quantization': 'int8',
      'ram_required': '4.5 GB',
      'tags': 'general,coding,reasoning,qwen,litert',
    },
    {
      'name': 'Qwen2.5-3B Instruct (Q4_K_M)',
      'filename': 'qwen2.5-3b-instruct-q4_k_m.gguf',
      'url':
          'https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q4_K_M.gguf',
      'size': '2.09 GB',
      'description':
          'Best overall balance of speed, intelligence, and memory efficiency for Android mobile devices',
      'template': 'chatml',
      'runtime': 'llama',
      'quantization': 'Q4_K_M',
      'ram_required': '3.5 GB',
      'tags': 'general,coding,reasoning,qwen,gguf',
    },
    {
      'name': 'Qwen 2.5 7B Instruct (LiteRT-LM)',
      'filename': 'Qwen2.5-7B-Instruct_multi-prefill-seq_q8_ekv4096.litertlm',
      'url':
          'https://huggingface.co/litert-community/Qwen2.5-7B-Instruct/resolve/main/Qwen2.5-7B-Instruct_multi-prefill-seq_q8_ekv4096.litertlm',
      'size': '7.18 GB',
      'description':
          'Flagship 7B LiteRT-LM model for ultra-tier devices with 12GB+ RAM; enterprise-grade local intelligence',
      'template': 'litert',
      'runtime': 'litert',
      'quantization': 'int8',
      'ram_required': '8.5 GB',
      'tags': 'flagship,coding,reasoning,qwen,litert',
    },
    {
      'name': 'Qwen2.5-7B Instruct (Q4_K_M)',
      'filename': 'qwen2.5-7b-instruct-q4_k_m.gguf',
      'url':
          'https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf',
      'size': '4.68 GB',
      'description':
          'Top-tier 7B parameter powerhouse for deep reasoning, structured code generation, and complex writing',
      'template': 'chatml',
      'runtime': 'llama',
      'quantization': 'Q4_K_M',
      'ram_required': '6.5 GB',
      'tags': 'flagship,coding,reasoning,qwen,gguf',
    },
    {
      'name': 'DeepSeek R1 Distill Qwen 1.5B (LiteRT-LM)',
      'filename':
          'DeepSeek-R1-Distill-Qwen-1.5B_multi-prefill-seq_q8_ekv4096.litertlm',
      'url':
          'https://huggingface.co/litert-community/DeepSeek-R1-Distill-Qwen-1.5B/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B_multi-prefill-seq_q8_ekv4096.litertlm',
      'size': '1.71 GB',
      'description':
          'DeepSeek-R1 reasoning distilled into Qwen 1.5B; outputs full chain-of-thought in <think> tags at high speed',
      'template': 'litert',
      'runtime': 'litert',
      'quantization': 'int8',
      'ram_required': '2.8 GB',
      'tags': 'reasoning,math,coding,deepseek,litert',
    },
    {
      'name': 'DeepSeek-R1-Distill-Qwen-1.5B (Q4_K_M)',
      'filename': 'deepseek-r1-distill-qwen-1.5b-q4_k_m.gguf',
      'url':
          'https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B-Q4_K_M.gguf',
      'size': '1.12 GB',
      'description':
          'DeepSeek R1 reasoning distilled for mobile llama.cpp engine with chain-of-thought thinking capability',
      'template': 'chatml',
      'runtime': 'llama',
      'quantization': 'Q4_K_M',
      'ram_required': '2.2 GB',
      'tags': 'reasoning,math,coding,deepseek,gguf',
    },
    {
      'name': 'DeepSeek-R1-Distill-Qwen-7B (Q4_K_M)',
      'filename': 'deepseek-r1-distill-qwen-7b-q4_k_m.gguf',
      'url':
          'https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-7B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-7B-Q4_K_M.gguf',
      'size': '4.68 GB',
      'description':
          'SOTA 7B reasoning model capable of complex mathematical proofs, step-by-step logic, and advanced coding',
      'template': 'chatml',
      'runtime': 'llama',
      'quantization': 'Q4_K_M',
      'ram_required': '6.8 GB',
      'tags': 'reasoning,flagship,math,coding,deepseek,gguf',
    },
    {
      'name': 'Gemma 2 2B Instruct (LiteRT-LM)',
      'filename': 'gemma-2-2b-it.litertlm',
      'url':
          'https://huggingface.co/litert-community/gemma-2-2b-it/resolve/main/gemma-2-2b-it.litertlm',
      'size': '2.41 GB',
      'description':
          'Google\'s official Gemma 2 2B tuned for LiteRT-LM on mobile devices with high conversational fluency',
      'template': 'litert',
      'runtime': 'litert',
      'quantization': 'int8',
      'ram_required': '3.5 GB',
      'tags': 'general,google,gemma,litert',
    },
    {
      'name': 'Gemma 2 2B Instruct (Q4_K_M)',
      'filename': 'gemma-2-2b-it-q4_k_m.gguf',
      'url':
          'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf',
      'size': '1.71 GB',
      'description':
          'Google\'s lightweight general chat model — fast, smart, and highly calibrated for general assistance',
      'template': 'gemma',
      'runtime': 'llama',
      'quantization': 'Q4_K_M',
      'ram_required': '2.8 GB',
      'tags': 'general,google,gemma,gguf',
    },
    {
      'name': 'Gemma 2 9B Instruct (LiteRT-LM)',
      'filename': 'gemma-2-9b-it.litertlm',
      'url':
          'https://huggingface.co/litert-community/gemma-2-9b-it/resolve/main/gemma-2-9b-it.litertlm',
      'size': '9.12 GB',
      'description':
          'Google Gemma 2 9B LiteRT-LM format for devices with 12GB+ RAM; exceptional knowledge and reasoning',
      'template': 'litert',
      'runtime': 'litert',
      'quantization': 'int8',
      'ram_required': '10.5 GB',
      'tags': 'flagship,google,gemma,litert',
    },
    {
      'name': 'Gemma 2 9B Instruct (Q4_K_M)',
      'filename': 'gemma-2-9b-it-q4_k_m.gguf',
      'url':
          'https://huggingface.co/bartowski/gemma-2-9b-it-GGUF/resolve/main/gemma-2-9b-it-Q4_K_M.gguf',
      'size': '5.88 GB',
      'description':
          'Google\'s top-tier Gemma 2 9B model; punches above its weight class in writing, analysis, and reasoning',
      'template': 'gemma',
      'runtime': 'llama',
      'quantization': 'Q4_K_M',
      'ram_required': '7.8 GB',
      'tags': 'flagship,google,gemma,reasoning,gguf',
    },
    {
      'name': 'Llama 3.2 1B Instruct (LiteRT-LM)',
      'filename': 'Llama-3.2-1B-Instruct.litertlm',
      'url':
          'https://huggingface.co/litert-community/Llama-3.2-1B-Instruct/resolve/main/Llama-3.2-1B-Instruct.litertlm',
      'size': '780 MB',
      'description':
          'Meta\'s ultra-compact Llama 3.2 1B model running on Google LiteRT with instant token generation',
      'template': 'litert',
      'runtime': 'litert',
      'quantization': 'int8',
      'ram_required': '1.6 GB',
      'tags': 'general,fast,meta,llama,litert',
    },
    {
      'name': 'Llama 3.2 1B Instruct (Q4_K_M)',
      'filename': 'llama-3.2-1b-instruct-q4_k_m.gguf',
      'url':
          'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
      'size': '805 MB',
      'description':
          'Meta ultra-efficient 1B model designed for on-device tasks, summarization, and fast chatting',
      'template': 'llama3',
      'runtime': 'llama',
      'quantization': 'Q4_K_M',
      'ram_required': '1.6 GB',
      'tags': 'general,fast,meta,llama,gguf',
    },
    {
      'name': 'Llama 3.2 3B Instruct (LiteRT-LM)',
      'filename': 'Llama-3.2-3B-Instruct.litertlm',
      'url':
          'https://huggingface.co/litert-community/Llama-3.2-3B-Instruct/resolve/main/Llama-3.2-3B-Instruct.litertlm',
      'size': '3.08 GB',
      'description':
          'Meta\'s flagship edge model with 3B parameters optimized for LiteRT-LM mobile hardware acceleration',
      'template': 'litert',
      'runtime': 'litert',
      'quantization': 'int8',
      'ram_required': '4.5 GB',
      'tags': 'general,balanced,meta,llama,litert',
    },
    {
      'name': 'Llama 3.2 3B Instruct (Q4_K_M)',
      'filename': 'llama-3.2-3b-instruct-q4_k_m.gguf',
      'url':
          'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
      'size': '2.02 GB',
      'description':
          'Meta Llama 3.2 3B GGUF with outstanding instruction following, creative writing, and concise answers',
      'template': 'llama3',
      'runtime': 'llama',
      'quantization': 'Q4_K_M',
      'ram_required': '3.5 GB',
      'tags': 'general,balanced,meta,llama,gguf',
    },
    {
      'name': 'SmolLM2-360M Instruct (Q4_K_M)',
      'filename': 'smollm2-360m-instruct-q4_k_m.gguf',
      'url':
          'https://huggingface.co/bartowski/SmolLM2-360M-Instruct-GGUF/resolve/main/SmolLM2-360M-Instruct-Q4_K_M.gguf',
      'size': '240 MB',
      'description':
          'Featherweight 360M model by HuggingFace; runs at 60+ TPS on any Android device with negligible RAM footprint',
      'template': 'chatml',
      'runtime': 'llama',
      'quantization': 'Q4_K_M',
      'ram_required': '0.8 GB',
      'tags': 'general,tiny,ultra-fast,smollm,gguf',
    },
    {
      'name': 'SmolLM2-1.7B Instruct (Q4_K_M)',
      'filename': 'smollm2-1.7b-instruct-q4_k_m.gguf',
      'url':
          'https://huggingface.co/bartowski/SmolLM2-1.7B-Instruct-GGUF/resolve/main/SmolLM2-1.7B-Instruct-Q4_K_M.gguf',
      'size': '1.05 GB',
      'description':
          'High-efficiency 1.7B general assistant from HuggingFace trained on curated synthetic data',
      'template': 'chatml',
      'runtime': 'llama',
      'quantization': 'Q4_K_M',
      'ram_required': '2.0 GB',
      'tags': 'general,fast,smollm,gguf',
    },
    {
      'name': 'Phi-3.5 Mini Instruct (Q4_K_M)',
      'filename': 'phi-3.5-mini-instruct-q4_k_m.gguf',
      'url':
          'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf',
      'size': '2.39 GB',
      'description':
          'Microsoft\'s state-of-the-art 3.8B reasoning & coding model; superior logic in a compact form factor',
      'template': 'phi',
      'runtime': 'llama',
      'quantization': 'Q4_K_M',
      'ram_required': '3.8 GB',
      'tags': 'reasoning,coding,microsoft,phi,gguf',
    },
    {
      'name': 'SD Turbo FP16 (SD Turbo)',
      'filename': 'sd_turbo_fp16.safetensors',
      'url':
          'https://huggingface.co/stabilityai/sd-turbo/resolve/main/sd_turbo.safetensors',
      'size': '2.04 GB',
      'description':
          'Stability AI real-time 1-step diffusion model for ultra-fast on-device image synthesis',
      'template': 'sd',
      'runtime': 'sd',
      'quantization': 'FP16',
      'ram_required': '4.5 GB',
      'tags': 'image,turbo,fast,sd',
    },
    {
      'name': 'DreamShaper 8 LCM (SD 1.5)',
      'filename': 'DreamShaper8_LCM.safetensors',
      'url':
          'https://huggingface.co/Lykon/dreamshaper-8-lcm/resolve/main/DreamShaper8_LCM.safetensors',
      'size': '2.13 GB',
      'description':
          'Extremely popular 4-step Latent Consistency Model for photorealistic and artistic image generation',
      'template': 'sd',
      'runtime': 'sd',
      'quantization': 'FP16',
      'ram_required': '4.5 GB',
      'tags': 'image,art,lcm,sd',
    },
    {
      'name': 'CyberRealistic V8 FP16 (SD 1.5)',
      'filename': 'CyberRealistic_V8_FP16.safetensors',
      'url':
          'https://huggingface.co/cyberdelia/CyberRealistic/resolve/main/CyberRealistic_V8_FP16.safetensors',
      'size': '2.13 GB',
      'description':
          'Photorealistic local image generation model calibrated in FP16 for mobile NPU/GPU/CPU generation',
      'template': 'sd',
      'runtime': 'sd',
      'quantization': 'FP16',
      'ram_required': '4.5 GB',
      'tags': 'image,photo,realistic,sd',
    },
    {
      'name': 'Realistic Vision V5.1 fp16 (SD 1.5)',
      'filename': 'Realistic_Vision_V5.1_fp16-no-ema.safetensors',
      'url':
          'https://huggingface.co/SG161222/Realistic_Vision_V5.1_noVAE/resolve/main/Realistic_Vision_V5.1_fp16-no-ema.safetensors',
      'size': '2.13 GB',
      'description':
          'Highly popular photorealistic portrait and scene model for mobile image generation',
      'template': 'sd',
      'runtime': 'sd',
      'quantization': 'FP16',
      'ram_required': '4.5 GB',
      'tags': 'image,photo,realistic,sd',
    },
    {
      'name': 'AnyLoRA (SD 1.5)',
      'filename': 'AnyLoRA_noVae_fp16-pruned.safetensors',
      'url':
          'https://huggingface.co/Lykon/AnyLoRA/resolve/main/AnyLoRA_noVae_fp16-pruned.safetensors',
      'size': '2.13 GB',
      'description':
          'Highly versatile Anime / Stylized image generator for artistic prompts',
      'template': 'sd',
      'runtime': 'sd',
      'quantization': 'FP16',
      'ram_required': '4.5 GB',
      'tags': 'image,anime,art,sd',
    },
    {
      'name': 'Qwen 3 0.6B (LiteRT-LM)',
      'filename': 'Qwen3-0.6B.litertlm',
      'url':
          'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/Qwen3-0.6B.litertlm',
      'size': '586 MB',
      'description':
          'Next-gen Qwen 3 compact chat model in LiteRT-LM format for low-RAM mobile devices',
      'template': 'litert',
      'runtime': 'litert',
      'quantization': 'int8',
      'ram_required': '1.2 GB',
      'tags': 'general,fast,tiny,qwen,litert',
    },
    {
      'name': 'Gemma 4 E2B Instruct (LiteRT-LM)',
      'filename': 'gemma-4-E2B-it.litertlm',
      'url':
          'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
      'size': '2.46 GB',
      'description':
          'Strong multimodal general chat LiteRT-LM model with vision understanding from Google Gemma',
      'template': 'litert',
      'runtime': 'litert',
      'quantization': 'int8',
      'ram_required': '3.8 GB',
      'vision': 'true',
      'tags': 'general,vision,google,gemma,litert',
    },
    {
      'name': 'Gemma 4 E4B Instruct (LiteRT-LM)',
      'filename': 'gemma-4-E4B-it.litertlm',
      'url':
          'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm',
      'size': '3.40 GB',
      'description':
          'Highest quality vision-enabled LiteRT-LM option for flagship phones with 6GB+ RAM',
      'template': 'litert',
      'runtime': 'litert',
      'quantization': 'int8',
      'ram_required': '5.0 GB',
      'vision': 'true',
      'tags': 'flagship,vision,google,gemma,litert',
    },
    {
      'name': 'Qwen2-VL-2B Instruct (Q4_K_M)',
      'filename': 'qwen2-vl-2b-instruct-q4_k_m.gguf',
      'url':
          'https://huggingface.co/bartowski/Qwen2-VL-2B-Instruct-GGUF/resolve/main/Qwen2-VL-2B-Instruct-Q4_K_M.gguf',
      'size': '1.30 GB',
      'description':
          'Vision-capable Qwen model — understands images, diagrams, charts, and document screenshots',
      'template': 'chatml',
      'runtime': 'llama',
      'quantization': 'Q4_K_M',
      'ram_required': '2.5 GB',
      'vision': 'true',
      'tags': 'vision,general,qwen,gguf',
    },
    {
      'name': 'Kimi Moonlight 16B-A3B Fast (IQ2_XXS)',
      'filename': 'moonlight-16b-a3b-instruct-iq2_xxs.gguf',
      'url':
          'https://huggingface.co/mmnga/Moonlight-16B-A3B-Instruct-gguf/resolve/main/Moonlight-16B-A3B-Instruct-IQ2_XXS.gguf?download=true',
      'size': '5.50 GB',
      'description':
          'Moonshot AI (Kimi) — Optimized 5.5GB 16B-A3B MoE model. Much faster download & lower RAM pressure.',
      'template': 'chatml',
      'runtime': 'llama',
      'quantization': 'IQ2_XXS',
      'ram_required': '6.5 GB',
      'tags': 'flagship,moe,kimi,fast,gguf',
    },
    {
      'name': 'Kimi Moonlight 16B-A3B Flagship (Q3_K_S)',
      'filename': 'moonlight-16b-a3b-instruct-q3_k_s.gguf',
      'url':
          'https://huggingface.co/mmnga/Moonlight-16B-A3B-Instruct-gguf/resolve/main/Moonlight-16B-A3B-Instruct-Q3_K_S.gguf?download=true',
      'size': '7.65 GB',
      'description':
          'Moonshot AI (Kimi) — 3B active parameter Mixture-of-Experts (MoE) flagship model. Large download (~7.6 GB), Wi-Fi recommended.',
      'template': 'chatml',
      'runtime': 'llama',
      'quantization': 'Q3_K_S',
      'ram_required': '8.5 GB',
      'tags': 'flagship,moe,kimi,reasoning,gguf',
    },
    {
      'name': 'Dolphin-3.0-Qwen2.5-1.5B (Q4_K_M)',
      'filename': 'dolphin-3.0-qwen2.5-1.5b-q4_k_m.gguf',
      'url':
          'https://huggingface.co/bartowski/Dolphin3.0-Qwen2.5-1.5B-GGUF/resolve/main/Dolphin3.0-Qwen2.5-1.5B-Q4_K_M.gguf',
      'size': '1.10 GB',
      'description':
          'Uncensored Dolphin 3.0 based on Qwen 2.5 — Fast, highly capable, and unrestricted',
      'template': 'chatml',
      'runtime': 'llama',
      'quantization': 'Q4_K_M',
      'ram_required': '2.2 GB',
      'tags': 'uncensored,general,qwen,gguf',
    },
    {
      'name': 'Llama-3.2-3B Uncensored (Q4_K_M)',
      'filename': 'llama-3.2-3b-instruct-uncensored-q4_k_m.gguf',
      'url':
          'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-uncensored-GGUF/resolve/main/Llama-3.2-3B-Instruct-uncensored-Q4_K_M.gguf',
      'size': '2.10 GB',
      'description':
          'Uncensored Llama 3.2 3B — Smarter, completely unfiltered assistance for creative and technical work',
      'template': 'llama3',
      'runtime': 'llama',
      'quantization': 'Q4_K_M',
      'ram_required': '3.5 GB',
      'tags': 'uncensored,general,llama,gguf',
    },
    {
      'name': 'SmolLM2-1.7B-Uncensored (Q4_K_M)',
      'filename': 'smollm2-1.7b-instruct-uncensored-q4_k_m.gguf',
      'url':
          'https://huggingface.co/mradermacher/SmolLM2-1.7B-Instruct-Uncensored-GGUF/resolve/main/SmolLM2-1.7B-Instruct-Uncensored.Q4_K_M.gguf',
      'size': '1.10 GB',
      'description':
          'Ultra-compact and unrestricted assistant for private queries without filtering',
      'template': 'chatml',
      'runtime': 'llama',
      'quantization': 'Q4_K_M',
      'ram_required': '2.0 GB',
      'tags': 'uncensored,general,smollm,gguf',
    },
    {
      'name': 'Gemma-2-2B-Abliterated (Q4_K_M)',
      'filename': 'gemma-2-2b-it-abliterated-q4_k_m.gguf',
      'url':
          'https://huggingface.co/bartowski/gemma-2-2b-it-abliterated-GGUF/resolve/main/gemma-2-2b-it-abliterated-Q4_K_M.gguf',
      'size': '1.60 GB',
      'description':
          'Abliterated Gemma 2 — Permanently uncensored, highly intelligent and concise',
      'template': 'gemma',
      'runtime': 'llama',
      'quantization': 'Q4_K_M',
      'ram_required': '2.8 GB',
      'tags': 'uncensored,google,gemma,gguf',
    },
    {
      'name': 'Ministral-3B Instruct (Q4_K_M)',
      'filename': 'ministral-3b-instruct-q4_k_m.gguf',
      'url':
          'https://huggingface.co/bartowski/ministral-3b-instruct-GGUF/resolve/main/ministral-3b-instruct-Q4_K_M.gguf',
      'size': '2.10 GB',
      'description':
          'Mistral AI flagship 3B edge model for fast, sharp, multilingual tasks',
      'template': 'mistral',
      'runtime': 'llama',
      'quantization': 'Q4_K_M',
      'ram_required': '3.5 GB',
      'tags': 'general,mistral,coding,gguf',
    },
  ];

  // Cloud API Endpoints
  static const String openaiEndpoint =
      'https://api.openai.com/v1/chat/completions';
  static const String anthropicEndpoint =
      'https://api.anthropic.com/v1/messages';
  static const String googleEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models';
  static const String kimiEndpoint =
      'https://api.moonshot.ai/v1/chat/completions';
  static const String stabilityEndpoint =
      'https://api.stability.ai/v2beta/stable-image/generate/sd3';
  static const String nvidiaEndpoint = 'https://integrate.api.nvidia.com/v1';
  static const String groqEndpoint = 'https://api.groq.com/openai/v1';
  static const String openRouterEndpoint = 'https://openrouter.ai/api/v1';
  static const String deepSeekEndpoint = 'https://api.deepseek.com';
}

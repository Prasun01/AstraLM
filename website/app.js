/* ─────────────────────────────────────────────────────────────
   AstraLM Showcase Interactive Scripts
   Features: 60fps Starfield Parallax, 3D Mockup Tilt,
             Live Simulator Workloads, RAM Spec Calculator
───────────────────────────────────────────────────────────── */

document.addEventListener('DOMContentLoaded', () => {
  initStarfield();
  initParallaxMouse();
  init3DPhoneTilt();
  initSimulator();
  initRamCalculator();
  initCopyButton();
});

// ── 1. 60 FPS Particle Starfield Canvas ──
function initStarfield() {
  const canvas = document.getElementById('starfieldCanvas');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');

  let width = (canvas.width = window.innerWidth);
  let height = (canvas.height = window.innerHeight);

  window.addEventListener('resize', () => {
    width = canvas.width = window.innerWidth;
    height = canvas.height = window.innerHeight;
  });

  const stars = [];
  const numStars = 140;

  for (let i = 0; i < numStars; i++) {
    stars.push({
      x: Math.random() * width,
      y: Math.random() * height,
      radius: Math.random() * 1.4 + 0.3,
      alpha: Math.random() * 0.7 + 0.2,
      speed: Math.random() * 0.25 + 0.05,
      direction: Math.random() * Math.PI * 2,
    });
  }

  let mouseX = 0;
  let mouseY = 0;
  window.addEventListener('mousemove', (e) => {
    mouseX = (e.clientX - width / 2) * 0.03;
    mouseY = (e.clientY - height / 2) * 0.03;
  });

  function render() {
    ctx.clearRect(0, 0, width, height);

    for (let star of stars) {
      star.y += star.speed;
      if (star.y > height) star.y = 0;
      if (star.y < 0) star.y = height;

      ctx.beginPath();
      ctx.arc(star.x + mouseX, star.y + mouseY, star.radius, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(220, 230, 255, ${star.alpha})`;
      ctx.fill();
    }

    requestAnimationFrame(render);
  }

  render();
}

// ── 2. Ambient Mesh Parallax ──
function initParallaxMouse() {
  const mesh1 = document.getElementById('mesh1');
  const mesh2 = document.getElementById('mesh2');
  const mesh3 = document.getElementById('mesh3');

  window.addEventListener('mousemove', (e) => {
    const x = (e.clientX / window.innerWidth - 0.5) * 40;
    const y = (e.clientY / window.innerHeight - 0.5) * 40;

    if (mesh1) mesh1.style.transform = `translate(${x * 1.2}px, ${y * 1.2}px)`;
    if (mesh2) mesh2.style.transform = `translate(${-x * 0.8}px, ${-y * 0.8}px)`;
    if (mesh3) mesh3.style.transform = `translate(${x * 0.5}px, ${-y * 0.5}px)`;
  });
}

// ── 3. 3D Floating Phone Tilt ──
function init3DPhoneTilt() {
  const wrapper = document.getElementById('phoneWrapper');
  const frame = document.getElementById('phone3D');
  if (!wrapper || !frame) return;

  wrapper.addEventListener('mousemove', (e) => {
    const rect = wrapper.getBoundingClientRect();
    const x = e.clientX - rect.left - rect.width / 2;
    const y = e.clientY - rect.top - rect.height / 2;

    const rotX = (-y / (rect.height / 2)) * 12;
    const rotY = (x / (rect.width / 2)) * 12;

    frame.style.transform = `rotateX(${rotX}deg) rotateY(${rotY}deg)`;
  });

  wrapper.addEventListener('mouseleave', () => {
    frame.style.transform = 'rotateX(0deg) rotateY(0deg)';
  });
}

// ── 4. Live Simulator Scenarios ──
const scenarios = {
  reasoning: {
    model: 'DeepSeek-R1-Distill-Qwen-1.5B (Local LiteRT)',
    tps: '38.4 tok/s',
    userPrompt: 'Solve logic puzzle: A farmer has 17 sheep, all but 9 die. How many are left?',
    thought: 'The phrasing states "all but 9 die". This is a linguistic trick question. "All but 9" implies that exactly 9 sheep survived while the rest perished. 17 - (17 - 9) = 9 sheep.',
    answer: `### Solution & Explanation\n\nThere are **9 sheep left**.\n\n**Key Insight:** The sentence specifies that *"all but 9 die"*, meaning exactly 9 sheep did not die and remain alive.`,
    hasCode: false,
    hasDoc: false,
  },
  pdf: {
    model: 'Qwen-2.5-3B-Instruct (Local GGUF)',
    tps: '27.8 tok/s',
    userPrompt: 'Draft an executive project roadmap PDF for Mobile AI Integration.',
    thought: 'Structuring executive document: H1 Project Title, Strategic Pillars (LiteRT NPU, GGUF Fallback, OpenXML DOCX/PDF export), Timeline milestones, Security compliance.',
    answer: `### Executive Project Roadmap: Sovereign Mobile AI\n\nThis blueprint outlines the Q1–Q3 transition to on-device zero-latency intelligence.`,
    hasCode: false,
    hasDoc: true,
    docName: 'Executive_AI_Roadmap_2026.pdf',
  },
  code: {
    model: 'Qwen-2.5-Coder-1.5B (Local LiteRT)',
    tps: '41.2 tok/s',
    userPrompt: 'Write a Dart class demonstrating zero-copy inference stream processing.',
    thought: 'Drafting clean Dart service utilizing GetX and FFI bindings for low-overhead token consumption...',
    answer: `Here is the high-throughput Dart stream processor:`,
    hasCode: true,
    codeLang: 'DART',
    codeSnippet: `class LiteRtStreamEngine {
  final _streamController = StreamController<String>.broadcast();
  Stream<String> get onToken => _streamController.stream;

  void processNativeChunk(Pointer<Utf8> chunkPtr) {
    final token = chunkPtr.toDartString();
    _streamController.add(token);
  }
}`,
    hasDoc: false,
  },
  cloud: {
    model: 'Claude 3.7 Sonnet (Anthropic API Cloud)',
    tps: 'Cloud API Stream',
    userPrompt: 'Compare on-device NPU compute efficiency vs Datacenter H100 clusters.',
    thought: 'Benchmarking Joules per token: Mobile NPUs operate at ~1.5W for 30 tok/s (0.05 J/token), whereas datacenter clusters require 700W+ plus networking transit latency.',
    answer: `### Efficiency Matrix: Edge NPU vs. Cloud H100\n\n- **Edge NPU:** 0.05 Joules/token · 0.0ms roundtrip · 100% data sovereignty.\n- **Cloud H100:** Massive throughput for 70B+ weights, but incurs serialization latency & recurring API billing.`,
    hasCode: false,
    hasDoc: false,
  },
};

function initSimulator() {
  const consoleBody = document.getElementById('consoleBody');
  const consoleModel = document.getElementById('consoleModelName');
  const consoleTps = document.getElementById('consoleTps');
  const presetBtns = document.querySelectorAll('.preset-btn');
  const sendBtn = document.getElementById('simSendBtn');
  const customInput = document.getElementById('simCustomInput');

  if (!consoleBody) return;

  function loadScenario(key) {
    const sc = scenarios[key] || scenarios.reasoning;
    if (consoleModel) consoleModel.querySelector('span').textContent = `Model: ${sc.model}`;
    if (consoleTps) consoleTps.textContent = sc.tps;

    let html = `
      <div class="chat-msg user-msg" style="margin-bottom: 16px;">
        <div class="user-text">${sc.userPrompt}</div>
      </div>
      <div class="chat-msg ai-msg">
        <div class="app-thought-box" style="margin-bottom: 14px;">
          <div class="thought-header">
            <div class="thought-bulb-pulse">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width: 14px; height: 14px; stroke: #38BDF8;"><path d="M9 18h6M10 22h4M12 2a7 7 0 0 0-7 7c0 2.5 1.5 4.5 3 6h8c1.5-1.5 3-3.5 3-6a7 7 0 0 0-7-7z"></path></svg>
            </div>
            <span class="thought-title" style="font-weight: 700; font-size: 12px; color: #FFF;">Thought Process</span>
            <span class="thought-timer" style="font-family: monospace; font-size: 11px; background: #1C2030; padding: 2px 6px; border-radius: 6px;">2.1s</span>
          </div>
          <div class="thought-body italic" style="font-style: italic; color: #8E95A8; font-size: 12px; line-height: 1.5;">
            ${sc.thought}
          </div>
        </div>
        <div class="app-answer-text" style="color: #E2E8F0; margin-bottom: 12px; line-height: 1.6;">
          ${sc.answer.replace(/\n\n/g, '<br><br>').replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>').replace(/### (.*?)\n/g, '<h3 style="margin-bottom: 8px; font-size: 15px; color: #FFF;">$1</h3>')}
        </div>
    `;

    if (sc.hasCode) {
      html += `
        <div class="app-code-box" style="margin-bottom: 14px;">
          <div class="code-box-header">
            <div class="code-lang">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width: 12px; height: 12px;"><polyline points="16 18 22 12 16 6"></polyline><polyline points="8 6 2 12 8 18"></polyline></svg>
              <span>${sc.codeLang}</span>
            </div>
            <button class="code-copy-btn" onclick="copySimCode(this)">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width: 12px; height: 12px;"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>
              <span>Copy</span>
            </button>
          </div>
          <pre style="padding: 12px; font-family: monospace; font-size: 12px; color: #E2E8F0; overflow-x: auto;"><code>${escapeHtml(sc.codeSnippet)}</code></pre>
        </div>
      `;
    }

    if (sc.hasDoc) {
      html += `
        <div class="app-doc-card" style="margin-bottom: 14px;">
          <div class="doc-card-info">
            <div class="doc-badge-icon">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width: 16px; height: 16px; stroke: #38BDF8;"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline></svg>
            </div>
            <div>
              <div class="doc-tag">DOCUMENT GENERATED</div>
              <div class="doc-name">${sc.docName}</div>
            </div>
          </div>
          <div class="doc-actions">
            <button class="doc-btn doc-pdf" onclick="simulateDownload('PDF')">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width: 12px; height: 12px;"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
              <span>Save PDF</span>
            </button>
            <button class="doc-btn doc-docx" onclick="simulateDownload('DOCX')">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width: 12px; height: 12px;"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path></svg>
              <span>Save DOCX</span>
            </button>
          </div>
        </div>
      `;
    }

    html += `
        <div class="app-action-bar">
          <div class="action-pill" onclick="showToast('Message copied to clipboard')">Copy</div>
          <div class="action-pill" onclick="simulateDownload('PDF')">PDF</div>
          <div class="action-pill" onclick="simulateDownload('DOCX')">DOCX</div>
          <div class="tok-speed" style="margin-left: auto;">${sc.tps}</div>
        </div>
      </div>
    `;

    consoleBody.innerHTML = html;
  }

  presetBtns.forEach((btn) => {
    btn.addEventListener('click', () => {
      presetBtns.forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');
      loadScenario(btn.dataset.scenario);
    });
  });

  if (sendBtn && customInput) {
    sendBtn.addEventListener('click', () => {
      const text = customInput.value.trim();
      if (!text) return;
      scenarios['custom'] = {
        model: 'DeepSeek-R1-Distill-1.5B (Local LiteRT)',
        tps: '37.8 tok/s',
        userPrompt: text,
        thought: `Synthesizing direct concise analysis for: "${text}" with zero cloud leakage...`,
        answer: `### Analysis for: ${text}\n\nAstraLM executed this response locally on your hardware. All context, embeddings, and KV caches were maintained strictly on-device.`,
        hasCode: false,
        hasDoc: text.toLowerCase().includes('pdf') || text.toLowerCase().includes('doc'),
        docName: 'AstraLM_Generated_Document.pdf',
      };
      presetBtns.forEach((b) => b.classList.remove('active'));
      loadScenario('custom');
      customInput.value = '';
    });

    customInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') sendBtn.click();
    });
  }

  loadScenario('reasoning');
}

// ── 5. RAM Hardware Calculator ──
const ramTiers = {
  4: {
    model: 'Qwen 2.5 0.5B / SmolLM2 1.7B',
    desc: 'Lightweight models tuned for 4GB memory limits',
    ctx: '1,024 – 2,048 tokens',
    ctxDesc: 'Compact context window optimized for single tasks',
    budget: '768 tokens',
    budgetDesc: 'Compact reasoning token budget',
    speed: '45 – 55 tok/s',
  },
  6: {
    model: 'Qwen 2.5 1.5B / DeepSeek R1 1.5B',
    desc: 'Sweet spot for balanced speed and reasoning',
    ctx: '2,048 – 4,096 tokens',
    ctxDesc: 'Multi-turn conversational context size',
    budget: '1,536 tokens',
    budgetDesc: 'Full reasoning budget for multi-step tasks',
    speed: '36 – 48 tok/s',
  },
  8: {
    model: 'DeepSeek R1 1.5B / Llama 3.2 3B',
    desc: 'Optimized for Galaxy A35 / Pixel / Snapdragon 8 devices',
    ctx: '4,096 tokens',
    ctxDesc: 'Full document processing & conversation history',
    budget: '2,560 tokens',
    budgetDesc: 'Generous allocation for deep thinking chains',
    speed: '32 – 45 tok/s',
  },
  12: {
    model: 'Llama 3.1 8B / Qwen 2.5 7B / DeepSeek R1 7B',
    desc: 'Flagship heavyweights with frontier-grade reasoning',
    ctx: '8,192 tokens',
    ctxDesc: 'Massive long-form context window',
    budget: '4,096 tokens',
    budgetDesc: 'Maximum reasoning depth',
    speed: '22 – 35 tok/s',
  },
};

function initRamCalculator() {
  const ramBtns = document.querySelectorAll('.ram-btn');
  const calcModel = document.getElementById('calcModel');
  const calcModelDesc = document.getElementById('calcModelDesc');
  const calcContext = document.getElementById('calcContext');
  const calcContextDesc = document.getElementById('calcContextDesc');
  const calcBudget = document.getElementById('calcBudget');
  const calcBudgetDesc = document.getElementById('calcBudgetDesc');
  const calcSpeed = document.getElementById('calcSpeed');

  if (!calcModel) return;

  ramBtns.forEach((btn) => {
    btn.addEventListener('click', () => {
      ramBtns.forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');

      const ram = btn.dataset.ram;
      const data = ramTiers[ram] || ramTiers[8];

      calcModel.textContent = data.model;
      calcModelDesc.textContent = data.desc;
      calcContext.textContent = data.ctx;
      calcContextDesc.textContent = data.ctxDesc;
      calcBudget.textContent = data.budget;
      calcBudgetDesc.textContent = data.budgetDesc;
      calcSpeed.textContent = data.speed;
    });
  });
}

// ── 6. Copy Code and Helpers ──
function initCopyButton() {
  const btn = document.getElementById('heroCodeCopy');
  if (!btn) return;
  btn.addEventListener('click', () => {
    const code = `import litert_lm as llm\nengine = llm.Engine.load("deepseek_r1_1.5b.bin")\nstream = engine.generate("Synthesize executive brief...")`;
    navigator.clipboard.writeText(code);
    btn.querySelector('span').textContent = 'Copied!';
    showToast('Code copied to clipboard');
    setTimeout(() => {
      btn.querySelector('span').textContent = 'Copy';
    }, 2000);
  });
}

function copySimCode(btn) {
  const code = btn.closest('.app-code-box').querySelector('code').innerText;
  navigator.clipboard.writeText(code);
  btn.querySelector('span').textContent = 'Copied!';
  showToast('Code snippet copied');
  setTimeout(() => {
    btn.querySelector('span').textContent = 'Copy';
  }, 2000);
}

function simulateDownload(type) {
  showToast(`Generating and exporting ${type} document...`);
  setTimeout(() => {
    showToast(`${type} document successfully saved!`);
  }, 800);
}

function showToast(msg) {
  const toast = document.getElementById('siteToast');
  const toastMsg = document.getElementById('toastMsg');
  if (!toast || !toastMsg) return;

  toastMsg.textContent = msg;
  toast.classList.add('show');
  setTimeout(() => {
    toast.classList.remove('show');
  }, 2600);
}

function escapeHtml(text) {
  const map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' };
  return text.replace(/[&<>"']/g, (m) => map[m]);
}

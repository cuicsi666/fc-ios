// FC 模拟器驱动（jsnes 内核）
// 暴露给原生层：window.loadRom(b64, name, gameId)、window.nesSetButton、window.nesPause 等
// 支持：虚拟摇杆（八方向）、低延迟音频、金手指（RAM 锁定 + Game Genie 码）

(function () {
  "use strict";

  var nes = null;
  var canvas = null;
  var ctx = null;
  var imageData = null;
  var audioCtx = null;
  var scriptNode = null;
  var sampleBuffer = [];
  var running = false;
  var paused = false;
  var frameId = null;
  var muted = false;

  // 音频参数
  var AUDIO_RATE = 44100;      // jsnes 输出采样率
  var AUDIO_BUF = 512;         // ScriptProcessor 缓冲区（小 → 低延迟）
  var TARGET_FILL = 1024;      // 目标预填充采样数（平衡延迟与 underrun）

  // 金手指状态
  var cheatsEnabled = false;
  var ramCheats = [];          // 每帧锁定的 RAM 地址 [{addr, value}]
  var currentGameId = null;

  function b64ToU8(b64) {
    var bin = atob(b64);
    var len = bin.length;
    var u8 = new Uint8Array(len);
    for (var i = 0; i < len; i++) u8[i] = bin.charCodeAt(i);
    return u8;
  }

  function u8ToStr(u8) {
    var str = "";
    for (var i = 0; i < u8.length; i++) str += String.fromCharCode(u8[i]);
    return str;
  }

  function ensureAudio() {
    if (audioCtx) return;
    try {
      var AC = window.AudioContext || window.webkitAudioContext;
      audioCtx = new AC({ sampleRate: AUDIO_RATE });
      // 若硬件不支持 44100，读回实际采样率
      if (audioCtx.sampleRate !== AUDIO_RATE) {
        AUDIO_RATE = audioCtx.sampleRate;
      }
      scriptNode = audioCtx.createScriptProcessor(AUDIO_BUF, 0, 1);
      scriptNode.onaudioprocess = function (e) {
        var out = e.outputBuffer.getChannelData(0);
        var n = out.length;
        if (muted || sampleBuffer.length < n) {
          for (var i = 0; i < n; i++) out[i] = 0;
          return;
        }
        for (var i = 0; i < n; i++) out[i] = sampleBuffer.shift();
      };
      scriptNode.connect(audioCtx.destination);
    } catch (err) {
      // 无声环境下静默
    }
  }

  function initCanvas() {
    canvas = document.getElementById("screen");
    if (!canvas) return;
    canvas.width = 256;
    canvas.height = 240;
    ctx = canvas.getContext("2d");
    imageData = ctx.createImageData(256, 240);
  }

  function renderFrame(frameBuffer) {
    if (!imageData) return;
    var data = imageData.data;
    var buf = new Uint32Array(frameBuffer);
    for (var i = 0; i < buf.length; i++) {
      var p = buf[i];
      var j = i * 4;
      data[j] = p & 0xff;
      data[j + 1] = (p >> 8) & 0xff;
      data[j + 2] = (p >> 16) & 0xff;
      data[j + 3] = 0xff;
    }
    ctx.putImageData(imageData, 0, 0);
  }

  function onAudioSample(l, r) {
    if (muted) return;
    sampleBuffer.push(l);
    // 防止累积过度导致延迟：超过上限丢弃最旧
    if (sampleBuffer.length > AUDIO_RATE) {
      sampleBuffer.splice(0, sampleBuffer.length - TARGET_FILL);
    }
  }

  function createNes() {
    nes = new window.jsnes.NES({
      onFrame: renderFrame,
      onAudioSample: onAudioSample,
    });
  }

  // 每帧应用 RAM 金手指（在 frame() 前锁定）
  function applyRamCheats() {
    if (!cheatsEnabled || !ramCheats.length || !nes) return;
    for (var i = 0; i < ramCheats.length; i++) {
      var c = ramCheats[i];
      nes.cpu.mem[c.addr] = c.value;
    }
  }

  function loop() {
    if (!running) return;
    frameId = requestAnimationFrame(loop);
    if (paused) return;
    try {
      applyRamCheats();
      nes.frame();
    } catch (e) {
      stop();
    }
  }

  function start() {
    if (running) return;
    ensureAudio();
    running = true;
    paused = false;
    // 预填充音频缓冲，降低启动 underrun
    if (sampleBuffer.length < TARGET_FILL) {
      for (var i = sampleBuffer.length; i < TARGET_FILL; i++) sampleBuffer.push(0);
    }
    frameId = requestAnimationFrame(loop);
    updatePauseUI();
  }

  function stop() {
    running = false;
    if (frameId) { cancelAnimationFrame(frameId); frameId = null; }
  }

  function updatePauseUI() {
    var el = document.getElementById("pauseLabel");
    if (el) el.textContent = paused ? "已暂停" : "运行中";
    var btn = document.getElementById("pauseBtn");
    if (btn) btn.textContent = paused ? "继续" : "暂停";
  }

  // ===== 金手指预设表 =====
  // type "ram" = 每帧锁定 RAM 地址（对"生命/状态"类有效）
  // type "gg"  = Game Genie 码（ROM 补丁，jsnes 原生支持，对"逻辑"类更稳）
  var CHEAT_PRESETS = {
    "super-mario": {
      name: "超级玛丽",
      cheats: [
        { label: "无敌", type: "ram", addr: 0x079E, value: 0x07 },
        { label: "无限时间", type: "ram", addr: 0x07FA, value: 0x09 },
        { label: "锁定 5 条命", type: "ram", addr: 0x075A, value: 0x05 },
      ]
    },
    "contra": {
      name: "魂斗罗",
      cheats: [
        { label: "无限生命", type: "gg", code: "SLAIUZ" },
        { label: "无敌(敌人无视)", type: "gg", code: "SLTIYG" },
        { label: "S 散弹枪", type: "gg", code: "LEIIXZ" },
      ]
    },
    "battle-city": {
      name: "坦克大战",
      cheats: [
        { label: "无敌", type: "gg", code: "SUEVGZVI" },
        { label: "无限生命", type: "gg", code: "SLESSTVI" },
      ]
    }
  };

  function buildRamCheats(gameId) {
    var preset = CHEAT_PRESETS[gameId];
    if (!preset) return [];
    var out = [];
    for (var i = 0; i < preset.cheats.length; i++) {
      var c = preset.cheats[i];
      if (c.type === "ram") out.push({ addr: c.addr, value: c.value });
    }
    return out;
  }

  // 应用 GG 码（ROM 补丁，需在 loadROM 后调用）
  function applyGGCodes(gameId) {
    var preset = CHEAT_PRESETS[gameId];
    if (!preset) return 0;
    var n = 0;
    try { nes.gameGenie.removeAllCodes(); } catch (e) {}
    for (var i = 0; i < preset.cheats.length; i++) {
      var c = preset.cheats[i];
      if (c.type === "gg" && c.code) {
        try {
          nes.gameGenie.addCode(c.code);
          n++;
        } catch (e) {}
      }
    }
    if (n > 0) nes.gameGenie.setEnabled(true);
    return n;
  }

  // ===== 对外接口 =====
  window.loadRom = function (b64, name, gameId) {
    try {
      initCanvas();
      createNes();
      var u8 = b64ToU8(b64);
      nes.loadROM(u8ToStr(u8));
      currentGameId = gameId || null;
      ramCheats = buildRamCheats(gameId || "");
      // 若金手指开启，应用 RAM 锁定 + GG 码
      if (cheatsEnabled) {
        applyGGCodes(gameId || "");
      } else {
        ramCheats = [];
      }
      var title = document.getElementById("gameTitle");
      if (title) title.textContent = name || "红白机";
      sampleBuffer = [];
      start();
      return { ok: true, name: name, cheats: ramCheats.length };
    } catch (err) {
      return { ok: false, error: String(err) };
    }
  };

  window.nesSetButton = function (btn, down) {
    if (!nes) return;
    var c = window.jsnes.Controller;
    var map = {
      A: c.BUTTON_A, B: c.BUTTON_B,
      SELECT: c.BUTTON_SELECT, START: c.BUTTON_START,
      UP: c.BUTTON_UP, DOWN: c.BUTTON_DOWN,
      LEFT: c.BUTTON_LEFT, RIGHT: c.BUTTON_RIGHT,
    };
    var code = map[btn];
    if (code === undefined) return;
    if (down) nes.buttonDown(1, code);
    else nes.buttonUp(1, code);
  };

  window.nesPause = function () {
    if (!nes) return false;
    paused = !paused;
    updatePauseUI();
    if (audioCtx && audioCtx.state === "suspended") audioCtx.resume();
    return paused;
  };

  window.nesReset = function () {
    if (!nes) return;
    try { nes.reset(); } catch (e) {}
    start();
  };

  window.nesMute = function (m) {
    muted = !!m;
    if (muted) sampleBuffer = [];
    return muted;
  };

  // 金手指开关
  window.nesSetCheat = function (enabled) {
    cheatsEnabled = !!enabled;
    if (cheatsEnabled) {
      ramCheats = buildRamCheats(currentGameId || "");
      applyGGCodes(currentGameId || "");
    } else {
      ramCheats = [];
      try { nes.gameGenie.removeAllCodes(); nes.gameGenie.setEnabled(false); } catch (e) {}
    }
    return { enabled: cheatsEnabled, count: ramCheats.length };
  };

  window.nesCheatState = function () {
    return { enabled: cheatsEnabled, count: ramCheats.length };
  };

  window.nesState = function () {
    return { running: running, paused: paused, muted: muted };
  };

  // 点击画面即启动音频（iOS 需要用户手势）
  document.addEventListener("DOMContentLoaded", function () {
    var tap = function () { ensureAudio(); if (audioCtx) audioCtx.resume(); };
    document.body.addEventListener("touchend", tap, { passive: true });
    document.body.addEventListener("click", tap);
  });

  updatePauseUI();
})();

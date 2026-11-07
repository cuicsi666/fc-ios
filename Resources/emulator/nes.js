// FC 模拟器驱动（jsnes 内核）
// 暴露给原生层：window.loadRom(base64, name)、window.nesSetButton、window.nesPause 等

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
  var lastTime = 0;
  var muted = false;

  // 音频采样缓冲，jsnes 以 44100Hz 输出
  var AUDIO_RATE = 44100;
  var AUDIO_BUF = 4096;

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
      scriptNode = audioCtx.createScriptProcessor(AUDIO_BUF, 0, 1);
      scriptNode.onaudioprocess = function (e) {
        var out = e.outputBuffer.getChannelData(0);
        if (muted || sampleBuffer.length === 0) {
          for (var i = 0; i < out.length; i++) out[i] = 0;
          return;
        }
        var n = Math.min(out.length, sampleBuffer.length);
        for (var i = 0; i < n; i++) out[i] = sampleBuffer.shift();
        for (var i = n; i < out.length; i++) out[i] = 0;
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
      data[j] = p & 0xff;           // R
      data[j + 1] = (p >> 8) & 0xff; // G
      data[j + 2] = (p >> 16) & 0xff;// B
      data[j + 3] = 0xff;
    }
    ctx.putImageData(imageData, 0, 0);
  }

  function onAudioSample(l, r) {
    if (muted) return;
    sampleBuffer.push(l);
    if (sampleBuffer.length > AUDIO_RATE * 2) {
      sampleBuffer.splice(0, sampleBuffer.length - AUDIO_RATE);
    }
  }

  function createNes() {
    nes = new window.jsnes.NES({
      onFrame: renderFrame,
      onAudioSample: onAudioSample,
    });
  }

  function loop(t) {
    if (!running) return;
    frameId = requestAnimationFrame(loop);
    if (paused) return;
    try {
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
    lastTime = performance.now();
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

  // ===== 对外接口 =====
  window.loadRom = function (b64, name) {
    try {
      initCanvas();
      createNes();
      var u8 = b64ToU8(b64);
      nes.loadROM(u8ToStr(u8));
      var title = document.getElementById("gameTitle");
      if (title) title.textContent = name || "红白机";
      sampleBuffer = [];
      start();
      return { ok: true, name: name };
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

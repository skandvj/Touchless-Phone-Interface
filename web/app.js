const TOTAL_TRIALS = 6;
const NUM_OPTIONS = 4;
const MOTION_THRESHOLD = 4;
const CLAP_DEBOUNCE_MS = 300;
const MOTION_DEBOUNCE_MS = 520;

const AppState = {
  READY: "ready",
  TRIAL: "trial",
  COMPLETE: "complete",
};

const state = {
  appState: AppState.READY,
  currentTrial: 0,
  currentPosition: 0,
  targetOption: 0,
  targetAction: 0,
  startTime: 0,
  finishTime: 0,
  lastClapTime: 0,
  motionBlockedUntil: 0,
  micLevel: 0,
  previousMicLevel: 0,
  audioReady: false,
  motionReady: false,
  zBaseline: null,
  zValue: null,
  audioFrame: null,
};

const els = {
  readyScreen: document.querySelector("#readyScreen"),
  trialScreen: document.querySelector("#trialScreen"),
  completeScreen: document.querySelector("#completeScreen"),
  startButton: document.querySelector("#startButton"),
  againButton: document.querySelector("#againButton"),
  trialPill: document.querySelector("#trialPill"),
  targetNumber: document.querySelector("#targetNumber"),
  actionWord: document.querySelector("#actionWord"),
  optionsGrid: document.querySelector("#optionsGrid"),
  currentLabel: document.querySelector("#currentLabel"),
  avgTime: document.querySelector("#avgTime"),
  totalTime: document.querySelector("#totalTime"),
  micStatus: document.querySelector("#micStatus"),
  micMeter: document.querySelector("#micMeter"),
  motionStatus: document.querySelector("#motionStatus"),
  invertMotion: document.querySelector("#invertMotion"),
  sensitivity: document.querySelector("#sensitivity"),
  testClap: document.querySelector("#testClap"),
  testUp: document.querySelector("#testUp"),
  testDown: document.querySelector("#testDown"),
};

let audioContext;
let analyser;
let audioData;
let micStream;

function randomInt(max) {
  return Math.floor(Math.random() * max);
}

function formatSeconds(ms, digits = 2) {
  return `${(ms / 1000).toFixed(digits)}s`;
}

function setScreen(screen) {
  els.readyScreen.classList.toggle("is-hidden", screen !== AppState.READY);
  els.trialScreen.classList.toggle("is-hidden", screen !== AppState.TRIAL);
  els.completeScreen.classList.toggle("is-hidden", screen !== AppState.COMPLETE);
}

function startTrial() {
  state.currentPosition = 0;
  state.targetOption = randomInt(NUM_OPTIONS);
  state.targetAction = randomInt(2);
  state.motionBlockedUntil = 0;
  render();
}

function resetRun() {
  state.appState = AppState.TRIAL;
  state.currentTrial = 0;
  state.startTime = performance.now();
  state.finishTime = 0;
  startTrial();
}

function goBackOneTrial() {
  if (state.currentTrial > 0) {
    state.currentTrial -= 1;
  }

  startTrial();
  state.motionBlockedUntil = performance.now() + MOTION_DEBOUNCE_MS;
}

function completeTrial() {
  state.currentTrial += 1;

  if (state.currentTrial < TOTAL_TRIALS) {
    startTrial();
  } else {
    state.finishTime = performance.now();
    state.appState = AppState.COMPLETE;
    render();
  }

  state.motionBlockedUntil = performance.now() + MOTION_DEBOUNCE_MS;
}

function onClapDetected() {
  if (state.appState !== AppState.TRIAL) {
    return;
  }

  state.currentPosition = (state.currentPosition + 1) % NUM_OPTIONS;
  render();
}

function onMotionAction(action) {
  if (state.appState !== AppState.TRIAL || performance.now() < state.motionBlockedUntil) {
    return;
  }

  if (state.currentPosition === state.targetOption && action === state.targetAction) {
    completeTrial();
  } else {
    goBackOneTrial();
  }
}

function renderOptions() {
  els.optionsGrid.innerHTML = "";

  for (let index = 0; index < NUM_OPTIONS; index += 1) {
    const tile = document.createElement("button");
    tile.className = "option-tile";
    tile.type = "button";
    tile.textContent = String(index + 1);
    tile.setAttribute("aria-label", `Block ${index + 1}`);
    tile.classList.toggle("is-current", index === state.currentPosition);
    tile.classList.toggle("is-target", index === state.targetOption);
    tile.addEventListener("click", () => {
      if (state.appState !== AppState.TRIAL) {
        return;
      }
      state.currentPosition = index;
      render();
    });

    els.optionsGrid.append(tile);
  }
}

function render() {
  setScreen(state.appState);
  els.trialPill.textContent =
    state.appState === AppState.TRIAL
      ? `Trial ${state.currentTrial + 1}/${TOTAL_TRIALS}`
      : state.appState === AppState.COMPLETE
        ? "Done"
        : "Ready";

  if (state.appState === AppState.TRIAL) {
    els.targetNumber.textContent = String(state.targetOption + 1);
    els.actionWord.textContent = state.targetAction === 0 ? "Phone Up" : "Phone Down";
    els.currentLabel.textContent = `Current: ${state.currentPosition + 1}`;
    renderOptions();
  }

  if (state.appState === AppState.COMPLETE) {
    const elapsed = state.finishTime - state.startTime;
    els.avgTime.textContent = formatSeconds(elapsed / TOTAL_TRIALS);
    els.totalTime.textContent = `Total time: ${formatSeconds(elapsed, 1)}`;
  }
}

async function requestMotionPermission() {
  if (!("DeviceMotionEvent" in window)) {
    els.motionStatus.textContent = "Unavailable";
    return;
  }

  if (typeof DeviceMotionEvent.requestPermission === "function") {
    const result = await DeviceMotionEvent.requestPermission();
    if (result !== "granted") {
      els.motionStatus.textContent = "Blocked";
      return;
    }
  }

  window.addEventListener("devicemotion", handleDeviceMotion, { passive: true });
  state.motionReady = true;
  els.motionStatus.textContent = "Listening";
}

function handleDeviceMotion(event) {
  const reading = event.accelerationIncludingGravity || event.acceleration;
  if (!reading || typeof reading.z !== "number") {
    return;
  }

  state.zValue = reading.z;
  if (state.zBaseline === null) {
    state.zBaseline = reading.z;
  }

  const delta = reading.z - state.zBaseline;
  els.motionStatus.textContent = `${delta.toFixed(1)}`;

  if (Math.abs(delta) > MOTION_THRESHOLD) {
    const normalizedDelta = els.invertMotion.checked ? delta * -1 : delta;
    onMotionAction(normalizedDelta > 0 ? 0 : 1);
    state.zBaseline = reading.z;
  }
}

async function requestMicrophone() {
  if (!navigator.mediaDevices?.getUserMedia) {
    els.micStatus.textContent = "Unavailable";
    return;
  }

  try {
    micStream = await navigator.mediaDevices.getUserMedia({
      audio: {
        echoCancellation: false,
        noiseSuppression: false,
        autoGainControl: false,
      },
    });

    audioContext = new (window.AudioContext || window.webkitAudioContext)();
    const source = audioContext.createMediaStreamSource(micStream);
    analyser = audioContext.createAnalyser();
    analyser.fftSize = 2048;
    audioData = new Uint8Array(analyser.fftSize);
    source.connect(analyser);

    state.audioReady = true;
    els.micStatus.textContent = "Listening";
    readAudio();
  } catch (error) {
    els.micStatus.textContent = "Blocked";
  }
}

function readAudio() {
  if (!analyser) {
    return;
  }

  analyser.getByteTimeDomainData(audioData);
  let sum = 0;

  for (let index = 0; index < audioData.length; index += 1) {
    const centered = (audioData[index] - 128) / 128;
    sum += centered * centered;
  }

  const rms = Math.sqrt(sum / audioData.length);
  const scaledLevel = rms * 1000;
  const spike = scaledLevel - state.previousMicLevel;
  const sensitivity = Number(els.sensitivity.value);
  const spikeThreshold = 125 - sensitivity;
  const levelThreshold = 110 - sensitivity * 0.72;
  const now = performance.now();

  state.micLevel = scaledLevel;
  els.micMeter.style.width = `${Math.min(100, scaledLevel * 1.6)}%`;

  if (
    scaledLevel > levelThreshold &&
    spike > spikeThreshold &&
    now - state.lastClapTime > CLAP_DEBOUNCE_MS
  ) {
    state.lastClapTime = now;
    onClapDetected();
  }

  state.previousMicLevel = scaledLevel * 0.7 + state.previousMicLevel * 0.3;
  state.audioFrame = requestAnimationFrame(readAudio);
}

async function prepareSensors() {
  els.startButton.disabled = true;
  els.startButton.textContent = "Starting";

  await Promise.allSettled([requestMicrophone(), requestMotionPermission()]);

  els.startButton.disabled = false;
  els.startButton.textContent = "Start";
}

function startFromReady() {
  resetRun();
  prepareSensors();
}

function installServiceWorker() {
  if (!("serviceWorker" in navigator)) {
    return;
  }

  const localHostnames = new Set(["localhost", "127.0.0.1", "::1"]);
  const isLocal = localHostnames.has(window.location.hostname);

  if (isLocal) {
    navigator.serviceWorker
      .getRegistrations()
      .then((registrations) => registrations.forEach((registration) => registration.unregister()))
      .catch(() => {});

    if ("caches" in window) {
      caches
        .keys()
        .then((keys) => keys.forEach((key) => caches.delete(key)))
        .catch(() => {});
    }

    return;
  }

  if (window.location.protocol === "https:") {
    navigator.serviceWorker.register("./sw.js").catch(() => {});
  }
}

els.startButton.addEventListener("click", startFromReady);
els.againButton.addEventListener("click", resetRun);
els.testClap.addEventListener("click", onClapDetected);
els.testUp.addEventListener("click", () => onMotionAction(0));
els.testDown.addEventListener("click", () => onMotionAction(1));

window.addEventListener("keydown", (event) => {
  if (event.code === "Space") {
    event.preventDefault();
    onClapDetected();
  }

  if (event.key === "ArrowUp") {
    onMotionAction(0);
  }

  if (event.key === "ArrowDown") {
    onMotionAction(1);
  }
});

window.addEventListener("beforeunload", () => {
  if (state.audioFrame) {
    cancelAnimationFrame(state.audioFrame);
  }

  if (micStream) {
    micStream.getTracks().forEach((track) => track.stop());
  }
});

render();
installServiceWorker();

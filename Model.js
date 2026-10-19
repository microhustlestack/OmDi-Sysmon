// Pure helpers for OmaDi.sysmon — no Qt imports so this stays Node-testable.

function parseStats(raw) {
  var stats = {
    cpu_temp_c: -1,
    cpu_pct: -1,
    mem_pct: -1,
    mem_used: "",
    mem_total: "",
    load1: "",
    disk_pct: -1,
    disk_avail: "",
    disk_mount: "/",
    fan_rpm: -1,
    batt_temp_c: -1,
    batt_voltage: "",
    batt_pct: -1,
    batt_status: "",
    net_rx_bytes: -1,
    net_tx_bytes: -1,
    gpu_temp_c: -1
  }
  if (!raw) return stats
  var parsed = null
  try {
    parsed = JSON.parse(String(raw))
  } catch (e) {
    return stats
  }
  if (parsed === null || typeof parsed !== "object") return stats
  for (var key in stats) {
    if (parsed[key] !== undefined && parsed[key] !== null) stats[key] = parsed[key]
  }
  return stats
}

function num(value, fallback) {
  var n = Number(value)
  if (!isFinite(n) || n < 0) return fallback === undefined ? -1 : fallback
  return n
}

function formatTemp(celsius) {
  var n = Number(celsius)
  if (!isFinite(n) || n < 0) return "--"
  return Math.round(n) + "°C"
}

function formatPct(value) {
  var n = Number(value)
  if (!isFinite(n) || n < 0) return "--"
  return Math.round(n) + "%"
}

function formatRpm(rpm) {
  var n = Number(rpm)
  if (!isFinite(n) || n <= 0) return "--"
  if (n >= 1000) return (n / 1000).toFixed(1) + "k RPM"
  return Math.round(n) + " RPM"
}

function formatBytes(bytes) {
  var n = Number(bytes)
  if (!isFinite(n) || n < 0) return "--"
  if (n < 1024) return Math.round(n) + " B"
  if (n < 1024 * 1024) return (n / 1024).toFixed(1) + " KB"
  if (n < 1024 * 1024 * 1024) return (n / (1024 * 1024)).toFixed(1) + " MB"
  return (n / (1024 * 1024 * 1024)).toFixed(2) + " GB"
}

function formatRate(bytesPerSec) {
  var n = Number(bytesPerSec)
  if (!isFinite(n) || n < 0) return "--"
  return formatBytes(n) + "/s"
}

// 0..1 fraction for progress bars; -1 when unknown.
function fraction(value) {
  var n = Number(value)
  if (!isFinite(n) || n < 0) return 0
  return Math.max(0, Math.min(1, n / 100))
}

function tempLevel(celsius) {
  var n = Number(celsius)
  if (!isFinite(n) || n < 0) return "unknown"
  if (n >= 85) return "critical"
  if (n >= 70) return "warm"
  return "ok"
}

function tempIcon(celsius) {
  var level = tempLevel(celsius)
  if (level === "critical") return ""
  if (level === "warm") return ""
  return ""
}

function barIcon() {
  return "󰻠"
}

function throughputState(previous, next, now) {
  var prev = previous || {}
  var sample = next || {}
  var rx = num(sample.net_rx_bytes, 0)
  var tx = num(sample.net_tx_bytes, 0)
  var prevTime = Number(prev.prevSampleTime || 0)
  if (!prevTime || now <= prevTime) {
    return { prevRx: rx, prevTx: tx, prevSampleTime: now, downRate: 0, upRate: 0, hasRate: false }
  }
  var dt = (now - prevTime) / 1000
  if (dt <= 0) {
    return { prevRx: rx, prevTx: tx, prevSampleTime: now, downRate: 0, upRate: 0, hasRate: false }
  }
  return {
    prevRx: rx,
    prevTx: tx,
    prevSampleTime: now,
    downRate: Math.max(0, (rx - Number(prev.prevRx || 0)) / dt),
    upRate: Math.max(0, (tx - Number(prev.prevTx || 0)) / dt),
    hasRate: true
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    parseStats: parseStats,
    num: num,
    formatTemp: formatTemp,
    formatPct: formatPct,
    formatRpm: formatRpm,
    formatBytes: formatBytes,
    formatRate: formatRate,
    fraction: fraction,
    tempLevel: tempLevel,
    tempIcon: tempIcon,
    barIcon: barIcon,
    throughputState: throughputState
  }
}

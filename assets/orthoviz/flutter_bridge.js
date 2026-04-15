// flutter_bridge.js
// ─────────────────────────────────────────────────────────────────────────────
// Injected by ImuWebViewBridge after Godot finishes loading.
//
// Data flow:
//   Flutter (_flushBatch) -> window.receiveSensorBatch(jsonStr)
//                         -> window._godotSensorBridge(json) -> Godot
// ─────────────────────────────────────────────────────────────────────────────

(function () {
  'use strict';

  let _godotReady = false;
  let _queue = []; // frames buffered before Godot is ready

  // ── Wait for Godot Engine to be ready ─────────────────────────────────────
  function waitForGodot(cb, interval = 100, maxTries = 150) {
    let tries = 0;
    const id = setInterval(() => {
      tries++;
      // Check for the exact callback that SensorBridge.gd registered!
      if (typeof window._godotSensorBridge === 'function') {
        clearInterval(id);
        cb();
      } else if (tries >= maxTries) {
        clearInterval(id);
        console.warn('[FlutterBridge] window._godotSensorBridge not found after timeout.');
        _godotReady = true; // allow queued frames to drain anyway
        _drainQueue();
      }
    }, interval);
  }

  // ── Send one sensor frame into Godot ──────────────────────────────────────
  function sendToGodot(frame) {
    try {
      // Call the function explicitly created by Godot's JavaScriptBridge
      if (typeof window._godotSensorBridge === 'function') {
        window._godotSensorBridge(JSON.stringify(frame));
      }
    } catch (e) {
      console.warn('[FlutterBridge] sendToGodot failed:', e);
    }
  }

  function _drainQueue() {
    while (_queue.length > 0) {
      sendToGodot(_queue.shift());
    }
  }

  // ── Public API called by Flutter (_flushBatch) ────────────────────────────
  // Called by Flutter with a JSON string: [ {sensor, ax, ay, az}, ... ]
  window.receiveSensorBatch = function (jsonStr) {
    let batch;
    try {
      batch = JSON.parse(jsonStr);
    } catch (e) {
      console.error('[FlutterBridge] JSON parse error:', e, jsonStr);
      return;
    }

    // Pass the raw data straight through to Godot!
    batch.forEach(frame => {
      // Safely handle different key names just in case Flutter sends 'sensorId' instead of 'sensor'
      const data = {
        sensor: frame.sensor || frame.sensorId, 
        ax: frame.ax ?? 0.0,
        ay: frame.ay ?? 0.0,
        az: frame.az ?? 9.8
      };

      if (!_godotReady) {
        _queue.push(data);
      } else {
        sendToGodot(data);
      }
    });
  };

  // Legacy single-sensor path: "sensorId|ax,ay,az"
  window.receiveIMUData = function (line) {
    const parts = line.split('|');
    if (parts.length !== 2) return;
    const csv = parts[1].split(',');
    if (csv.length !== 3) return;
    
    window.receiveSensorBatch(JSON.stringify([{
      sensor: parts[0].trim(),
      ax: parseFloat(csv[0]),
      ay: parseFloat(csv[1]),
      az: parseFloat(csv[2]),
    }]));
  };

  // ── Wait and mark ready ───────────────────────────────────────────────────
  waitForGodot(() => {
    _godotReady = true;
    _drainQueue();
    console.info('[FlutterBridge] Bridge live — Godot ready');
  });

  console.info('[FlutterBridge] Injected and waiting for Godot...');
})();
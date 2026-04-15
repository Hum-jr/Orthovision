import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

// ── Data model ───────────────────────────────────────────────────────────────
class ImuFrame {
  final String sensorId;
  final double ax, ay, az;
  final double pitchDeg, rollDeg, yawDeg;
  final int timestamp;

  const ImuFrame({
    required this.sensorId,
    required this.ax,
    required this.ay,
    required this.az,
    required this.pitchDeg,
    required this.rollDeg,
    this.yawDeg = 0,
    required this.timestamp,
  });

  @override
  String toString() =>
      'ImuFrame($sensorId  pitch:${pitchDeg.toStringAsFixed(1)}°'
      '  roll:${rollDeg.toStringAsFixed(1)}°)';
}

// ── Widget ────────────────────────────────────────────────────────────────────
class ImuWebViewBridge extends StatefulWidget {
  final Map<String, ImuFrame> latestFrames; // <-- Now accepting real data!
  
  // Kept so it doesn't break your existing main.dart structure
  final void Function(ImuFrame frame)? onFrame;
  final Duration batchInterval;

  const ImuWebViewBridge({
    super.key,
    required this.latestFrames,
    this.onFrame,
    this.batchInterval = const Duration(milliseconds: 16),
  });

  @override
  State<ImuWebViewBridge> createState() => _ImuWebViewBridgeState();
}

class _ImuWebViewBridgeState extends State<ImuWebViewBridge> {
  InAppWebViewController? _ctrl;
  bool _webReady = false;

  // This is the magic! Whenever main.dart gets new ESP32 data, it rebuilds
  // this widget, triggering this function to instantly push data to Godot.
  @override
  void didUpdateWidget(covariant ImuWebViewBridge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_webReady && _ctrl != null && widget.latestFrames.isNotEmpty) {
      _sendToGodot(widget.latestFrames.values.toList());
    }
  }

  void _sendToGodot(List<ImuFrame> frames) {
    final batch = frames.map((f) => {
          'sensor': f.sensorId,
          'ax': f.ax,
          'ay': f.ay,
          'az': f.az,
        }).toList();

    final safe = jsonEncode(batch).replaceAll("'", "\\'");
    _ctrl!.evaluateJavascript(source: "window.receiveSensorBatch('$safe');");
  }

  Future<void> _inject(InAppWebViewController ctrl) async {
    final js = await rootBundle.loadString('assets/orthoviz/flutter_bridge.js');
    await ctrl.evaluateJavascript(source: js);
    _webReady = true;
    debugPrint('[ImuBridge] flutter_bridge.js injected — bridge live');
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri('http://localhost:8080/ortho.html'),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled:                true,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback:        true,
        transparentBackground:            true,
        isInspectable:                    true,
        allowFileAccessFromFileURLs:      true,
        allowUniversalAccessFromFileURLs: true,
        allowContentAccess:               true,
      ),
      onWebViewCreated: (ctrl) {
        _ctrl = ctrl;
      },
      onLoadStop: (ctrl, url) async {
        debugPrint('[ImuBridge] Godot loaded: $url');
        await _inject(ctrl);
      },
      onReceivedError: (ctrl, req, err) =>
          debugPrint('[ImuBridge] Error: ${err.description}'),
    );
  }
}
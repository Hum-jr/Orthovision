import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'imu_webview_bridge.dart';

// ── Recording state ───────────────────────────────────────────────────────────

enum RecordingState { idle, recording, playing }

// A single timestamped snapshot of ALL active sensors
class MotionSnapshot {
  final int timestamp; // ms since recording start
  final Map<String, ImuFrame> frames;

  const MotionSnapshot({required this.timestamp, required this.frames});

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'frames': frames.map((k, v) => MapEntry(k, {
              'sensorId': v.sensorId,
              'pitchDeg': v.pitchDeg,
              'rollDeg': v.rollDeg,
              'yawDeg': v.yawDeg,
              'ax': v.ax,
              'ay': v.ay,
              'az': v.az,
              'timestamp': v.timestamp,
            })),
      };
}

// A named recording clip
class MotionClip {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<MotionSnapshot> snapshots;
  final Set<String> sensorIds;

  MotionClip({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.snapshots,
    required this.sensorIds,
  });

  Duration get duration {
    if (snapshots.isEmpty) return Duration.zero;
    return Duration(
        milliseconds: snapshots.last.timestamp - snapshots.first.timestamp);
  }

  int get frameCount => snapshots.length;
}

// ── Recording Service (singleton) ────────────────────────────────────────────

class RecordingService extends ChangeNotifier {
  static final RecordingService _instance = RecordingService._internal();
  factory RecordingService() => _instance;
  RecordingService._internal();

  RecordingState _state = RecordingState.idle;
  RecordingState get state => _state;

  final List<MotionClip> _clips = [];
  List<MotionClip> get clips => List.unmodifiable(_clips);

  // ── Active recording ──
  List<MotionSnapshot> _recordingBuffer = [];
  DateTime? _recordingStart;
  int _clipCounter = 1;

  // ── Playback ──
  MotionClip? _playingClip;
  MotionClip? get playingClip => _playingClip;
  int _playbackIndex = 0;
  Timer? _playbackTimer;
  double _playbackProgress = 0.0;
  double get playbackProgress => _playbackProgress;

  // Callback so the UI can receive replayed frames
  void Function(Map<String, ImuFrame>)? onPlaybackFrame;

  // ── Record ────────────────────────────────────────────────────────────────

  void startRecording() {
    if (_state != RecordingState.idle) return;
    _recordingBuffer = [];
    _recordingStart = DateTime.now();
    _state = RecordingState.recording;
    notifyListeners();
  }

  void addFrame(Map<String, ImuFrame> frames) {
    if (_state != RecordingState.recording) return;
    final elapsed =
        DateTime.now().difference(_recordingStart!).inMilliseconds;
    _recordingBuffer.add(MotionSnapshot(
      timestamp: elapsed,
      frames: Map.of(frames),
    ));
  }

  MotionClip? stopRecording({String? name}) {
    if (_state != RecordingState.recording) return null;
    _state = RecordingState.idle;

    if (_recordingBuffer.isEmpty) {
      notifyListeners();
      return null;
    }

    final sensorIds = <String>{};
    for (final snap in _recordingBuffer) {
      sensorIds.addAll(snap.frames.keys);
    }

    final clip = MotionClip(
      id: 'clip_${DateTime.now().millisecondsSinceEpoch}',
      name: name ?? 'Recording $_clipCounter',
      createdAt: DateTime.now(),
      snapshots: List.of(_recordingBuffer),
      sensorIds: sensorIds,
    );
    _clipCounter++;
    _clips.insert(0, clip);
    _recordingBuffer = [];
    _recordingStart = null;
    notifyListeners();
    return clip;
  }

  void discardRecording() {
    _state = RecordingState.idle;
    _recordingBuffer = [];
    _recordingStart = null;
    notifyListeners();
  }

  // ── Playback ──────────────────────────────────────────────────────────────

  void playClip(MotionClip clip) {
    stopPlayback();
    if (clip.snapshots.isEmpty) return;

    _playingClip = clip;
    _playbackIndex = 0;
    _playbackProgress = 0;
    _state = RecordingState.playing;
    notifyListeners();

    _scheduleNextFrame();
  }

  void _scheduleNextFrame() {
    if (_playbackIndex >= _playingClip!.snapshots.length) {
      stopPlayback();
      return;
    }

    final current = _playingClip!.snapshots[_playbackIndex];
    final nextIndex = _playbackIndex + 1;

    int delayMs = 16; // ~60fps default
    if (nextIndex < _playingClip!.snapshots.length) {
      delayMs = _playingClip!.snapshots[nextIndex].timestamp - current.timestamp;
      delayMs = delayMs.clamp(8, 500);
    }

    // Emit this frame
    onPlaybackFrame?.call(current.frames);
    _playbackProgress = current.timestamp /
        _playingClip!.snapshots.last.timestamp.toDouble();
    notifyListeners();

    _playbackIndex = nextIndex;
    _playbackTimer = Timer(Duration(milliseconds: delayMs), _scheduleNextFrame);
  }

  void stopPlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _playbackIndex = 0;
    _playbackProgress = 0;
    _playingClip = null;
    _state = RecordingState.idle;
    notifyListeners();
  }

  void deleteClip(String clipId) {
    _clips.removeWhere((c) => c.id == clipId);
    notifyListeners();
  }

  // ── Duration while recording ──────────────────────────────────────────────

  Duration get currentRecordingDuration {
    if (_state != RecordingState.recording || _recordingStart == null) {
      return Duration.zero;
    }
    return DateTime.now().difference(_recordingStart!);
  }
}

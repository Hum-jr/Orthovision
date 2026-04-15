import 'dart:async';
import 'package:flutter/material.dart';
import 'recording_service.dart';
import 'imu_webview_bridge.dart';

// ── Recordings View ───────────────────────────────────────────────────────────
// Drop this into the IndexedStack in main.dart as the 3rd tab
// (replacing or alongside ProgressView).

class RecordingsView extends StatefulWidget {
  final Map<String, ImuFrame> latestFrames;
  final RecordingService recordingService;

  const RecordingsView({
    super.key,
    required this.latestFrames,
    required this.recordingService,
  });

  @override
  State<RecordingsView> createState() => _RecordingsViewState();
}

class _RecordingsViewState extends State<RecordingsView> {
  Timer? _uiTimer; // ticks every second while recording to update elapsed time

  @override
  void initState() {
    super.initState();
    widget.recordingService.addListener(_onServiceChange);
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    widget.recordingService.removeListener(_onServiceChange);
    super.dispose();
  }

  void _onServiceChange() {
    if (!mounted) return;
    setState(() {});
    // Keep the elapsed timer ticking while recording
    if (widget.recordingService.state == RecordingState.recording) {
      _uiTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _uiTimer?.cancel();
      _uiTimer = null;
    }
  }

  // ── Recording controls ────────────────────────────────────────────────────

  void _toggleRecording() {
    final svc = widget.recordingService;
    if (svc.state == RecordingState.recording) {
      _promptSaveClip();
    } else if (svc.state == RecordingState.idle) {
      svc.startRecording();
    }
  }

  void _promptSaveClip() {
    final controller = TextEditingController(
      text: 'Recording ${widget.recordingService.clips.length + 1}',
    );
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save recording'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Clip name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.recordingService.discardRecording();
              Navigator.pop(ctx);
            },
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () {
              widget.recordingService.stopRecording(name: controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _playClip(MotionClip clip) {
    widget.recordingService.playClip(clip);
  }

  void _stopPlayback() {
    widget.recordingService.stopPlayback();
  }

  void _deleteClip(MotionClip clip) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${clip.name}"?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700),
            onPressed: () {
              widget.recordingService.deleteClip(clip.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final svc = widget.recordingService;

    return Column(
      children: [
        // ── Record control bar ──────────────────────────────────────────────
        _RecordBar(
          state: svc.state,
          elapsed: svc.currentRecordingDuration,
          frameCount: svc.state == RecordingState.recording
              ? null // buffer count not exposed directly
              : null,
          onToggle: _toggleRecording,
          onStop: svc.state == RecordingState.playing ? _stopPlayback : null,
          playingClip: svc.playingClip,
          playbackProgress: svc.playbackProgress,
        ),

        // ── Clip list ───────────────────────────────────────────────────────
        Expanded(
          child: svc.clips.isEmpty
              ? _EmptyClips()
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: svc.clips.length,
                  itemBuilder: (context, i) {
                    final clip = svc.clips[i];
                    final isPlaying =
                        svc.playingClip?.id == clip.id;
                    return _ClipCard(
                      clip: clip,
                      isPlaying: isPlaying,
                      playbackProgress:
                          isPlaying ? svc.playbackProgress : 0,
                      onPlay: () => _playClip(clip),
                      onStop: _stopPlayback,
                      onDelete: () => _deleteClip(clip),
                      scheme: scheme,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Record bar ────────────────────────────────────────────────────────────────

class _RecordBar extends StatelessWidget {
  final RecordingState state;
  final Duration elapsed;
  final int? frameCount;
  final VoidCallback onToggle;
  final VoidCallback? onStop;
  final MotionClip? playingClip;
  final double playbackProgress;

  const _RecordBar({
    required this.state,
    required this.elapsed,
    required this.frameCount,
    required this.onToggle,
    this.onStop,
    this.playingClip,
    required this.playbackProgress,
  });

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // ── Playback bar ──
    if (state == RecordingState.playing && playingClip != null) {
      return Container(
        color: scheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.play_circle_filled_rounded,
                    color: scheme.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Playing: ${playingClip!.name}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.stop_rounded),
                  color: scheme.error,
                  iconSize: 22,
                  onPressed: onStop,
                  tooltip: 'Stop playback',
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: playbackProgress,
                minHeight: 4,
                backgroundColor: scheme.surface,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
            ),
          ],
        ),
      );
    }

    // ── Recording bar ──
    final isRecording = state == RecordingState.recording;
    return Container(
      color: isRecording
          ? Colors.red.withOpacity(0.06)
          : scheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Pulsing record indicator
          if (isRecording) ...[
            _PulsingDot(),
            const SizedBox(width: 10),
            Text(
              _formatDuration(elapsed),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: Colors.red.shade400),
            ),
            const SizedBox(width: 6),
            Text('Recording...',
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant)),
          ] else ...[
            Icon(Icons.fiber_manual_record_rounded,
                size: 14, color: Colors.red.shade400),
            const SizedBox(width: 8),
            const Text('Record motion',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ],
          const Spacer(),
          FilledButton.icon(
            onPressed: onToggle,
            style: FilledButton.styleFrom(
              backgroundColor:
                  isRecording ? Colors.red.shade700 : scheme.primary,
            ),
            icon: Icon(
                isRecording ? Icons.stop_rounded : Icons.fiber_manual_record_rounded,
                size: 18),
            label: Text(isRecording ? 'Stop' : 'Record'),
          ),
        ],
      ),
    );
  }
}

// ── Pulsing red dot ───────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ── Clip card ─────────────────────────────────────────────────────────────────

class _ClipCard extends StatelessWidget {
  final MotionClip clip;
  final bool isPlaying;
  final double playbackProgress;
  final VoidCallback onPlay;
  final VoidCallback onStop;
  final VoidCallback onDelete;
  final ColorScheme scheme;

  const _ClipCard({
    required this.clip,
    required this.isPlaying,
    required this.playbackProgress,
    required this.onPlay,
    required this.onStop,
    required this.onDelete,
    required this.scheme,
  });

  String _formatDuration(Duration d) {
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}s';
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day) {
      return 'Today ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPlaying
            ? scheme.primary.withOpacity(0.07)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPlaying
              ? scheme.primary.withOpacity(0.4)
              : scheme.outlineVariant.withOpacity(0.4),
          width: isPlaying ? 1 : 0.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPlaying
                      ? Icons.play_arrow_rounded
                      : Icons.movie_rounded,
                  size: 20,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              // Name + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clip.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_formatDuration(clip.duration)}  ·  ${clip.frameCount} frames  ·  ${_formatDate(clip.createdAt)}',
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              // Actions
              IconButton(
                icon: Icon(
                  isPlaying
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                  size: 22,
                ),
                color: isPlaying ? scheme.error : scheme.primary,
                onPressed: isPlaying ? onStop : onPlay,
                tooltip: isPlaying ? 'Stop' : 'Play',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: scheme.onSurfaceVariant,
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
            ],
          ),

          // Sensor chips
          if (clip.sensorIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: clip.sensorIds.map((id) {
                return _SensorChip(sensorId: id, scheme: scheme);
              }).toList(),
            ),
          ],

          // Playback progress bar
          if (isPlaying) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: playbackProgress,
                minHeight: 3,
                backgroundColor: scheme.surface,
                valueColor:
                    AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Sensor chip ───────────────────────────────────────────────────────────────

class _SensorChip extends StatelessWidget {
  final String sensorId;
  final ColorScheme scheme;

  const _SensorChip({required this.sensorId, required this.scheme});

  static const Map<String, String> _shortLabels = {
    'mixamorig_LeftLeg': 'L Knee',
    'mixamorig_RightLeg': 'R Knee',
    'mixamorig_LeftUpLeg': 'L Thigh',
    'mixamorig_RightUpLeg': 'R Thigh',
    'mixamorig_Hips': 'Pelvis',
    'mixamorig_Spine': 'Trunk',
    'mixamorig_LeftFoot': 'L Ankle',
    'mixamorig_RightFoot': 'R Ankle',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _shortLabels[sensorId] ?? sensorId,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: scheme.primary),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyClips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.movie_creation_outlined,
              size: 48, color: scheme.onSurfaceVariant.withOpacity(0.4)),
          const SizedBox(height: 14),
          Text(
            'No recordings yet',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            'Hit Record while a sensor is connected\nto capture motion data.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

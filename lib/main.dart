import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

import 'imu_webview_bridge.dart';
import 'exercises_view.dart';
import 'progress_view.dart';
import 'settings_view.dart';
import 'recordings_view.dart';
import 'recording_service.dart';

// ── 1. Localhost server for Godot web export ──────────────────────────────────
final InAppLocalhostServer localhostServer = InAppLocalhostServer(
  documentRoot: 'assets/orthoviz',
  port: 8080,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  await localhostServer.start();
  runApp(const OrthovisionApp());
}

class OrthovisionApp extends StatelessWidget {
  const OrthovisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orthovision',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

// ── Dashboard (root scaffold) ─────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Map<String, ImuFrame> _latestFrames = {};
  int _selectedIndex = 0;

  // ── Connection state shown in top bar ──
  bool _sensorsConnected = false;
  int _activeSensors = 0;

  Timer? _espTimer;

  // ── Shared recording service ──
  final RecordingService _recordingService = RecordingService();

  @override
  void initState() {
    super.initState();
    // Wire playback frames back into the live frames map
    _recordingService.onPlaybackFrame = (frames) {
      if (mounted) setState(() => _latestFrames
        ..clear()
        ..addAll(frames));
    };
    _startEspTelemetry();
  }

  void _startEspTelemetry() {
    _espTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      // Don't overwrite frames during playback
      if (_recordingService.state == RecordingState.playing) return;

      try {
        final response = await http
            .get(Uri.parse('http://192.168.4.1/data'))
            .timeout(const Duration(milliseconds: 150));

        if (response.statusCode == 200) {
          final parts = response.body.split(',');

          if (parts.length >= 4) {
            String dynamicSensorId = parts[0];
            double x = double.parse(parts[1]);
            double y = double.parse(parts[2]);
            double z = double.parse(parts[3]);

            double pitch = atan2(-x, sqrt(y * y + z * z)) * 180 / pi;
            double roll = atan2(y, z) * 180 / pi;

            final frame = ImuFrame(
              sensorId: dynamicSensorId,
              pitchDeg: pitch,
              rollDeg: roll,
              yawDeg: 0.0,
              ax: x,
              ay: y,
              az: z,
              timestamp: DateTime.now().millisecondsSinceEpoch,
            );

            setState(() {
              _latestFrames[frame.sensorId] = frame;
              _sensorsConnected = true;
              _activeSensors = _latestFrames.length;
            });

            // Feed the frame into the recorder if active
            _recordingService.addFrame(_latestFrames);
          }
        }
      } catch (e) {
        if (_sensorsConnected) {
          setState(() {
            _sensorsConnected = false;
            _activeSensors = 0;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _espTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const _AppBarTitle(),
        backgroundColor: scheme.surfaceContainerHighest,
        elevation: 0,
        actions: [
          // ── Recording indicator (shown while recording) ──
          if (_recordingService.state == RecordingState.recording)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text('REC',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade400)),
                    ],
                  ),
                ),
              ),
            ),
          // ── Live sensor indicator ──
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _SensorIndicator(
              connected: _sensorsConnected,
              count: _activeSensors,
            ),
          ),
          // ── Patient chip ──
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: scheme.outlineVariant, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: scheme.primary.withOpacity(0.2),
                      child: Text(
                        'BH',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: scheme.primary),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('Ben Hamphrey',
                        style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _recordingService,
        builder: (context, _) {
          return IndexedStack(
            index: _selectedIndex,
            children: [
              // 0 – Monitor
              _HomeView(
                latestFrames: _latestFrames,
                onFrame: (frame) {
                  setState(() => _latestFrames[frame.sensorId] = frame);
                },
              ),
              // 1 – Exercises
              const ExercisesView(),
              // 2 – Recordings
              RecordingsView(
                latestFrames: _latestFrames,
                recordingService: _recordingService,
              ),
              // 3 – Progress
              const ProgressView(),
              // 4 – Settings (receives live frames for dynamic sensor list)
              SettingsView(latestFrames: _latestFrames),
            ],
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            selectedIcon: Icon(Icons.home_rounded),
            icon: Icon(Icons.home_outlined),
            label: 'Monitor',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.fitness_center_rounded),
            icon: Icon(Icons.fitness_center_outlined),
            label: 'Exercises',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.videocam_rounded),
            icon: Icon(Icons.videocam_outlined),
            label: 'Recordings',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.auto_graph_rounded),
            icon: Icon(Icons.auto_graph_outlined),
            label: 'Progress',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.settings_rounded),
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// ── Home View (unchanged from original) ──────────────────────────────────────

class _HomeView extends StatelessWidget {
  final Map<String, ImuFrame> latestFrames;
  final ValueChanged<ImuFrame> onFrame;

  const _HomeView({required this.latestFrames, required this.onFrame});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AlertBanner(frames: latestFrames),
        Expanded(
          flex: 6,
          child: Container(
            color: Colors.black,
            child: ImuWebViewBridge(
              batchInterval: const Duration(milliseconds: 16),
              onFrame: onFrame,
              latestFrames: latestFrames,
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: latestFrames.isEmpty
              ? const _AwaitingTelemetry()
              : _TelemetryGrid(frames: latestFrames),
        ),
      ],
    );
  }
}

// ── Alert banner ──────────────────────────────────────────────────────────────

class _AlertBanner extends StatelessWidget {
  final Map<String, ImuFrame> frames;
  const _AlertBanner({required this.frames});

  @override
  Widget build(BuildContext context) {
    final overRange = frames.values.any(
      (f) =>
          (f.sensorId == 'mixamorig_LeftLeg' ||
              f.sensorId == 'mixamorig_RightLeg') &&
          f.pitchDeg.abs() > 110,
    );

    if (!overRange && frames.isNotEmpty) {
      return Container(
        color: Colors.teal.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded,
                size: 15, color: Colors.tealAccent.shade700),
            const SizedBox(width: 8),
            Text(
              'All joint angles within safe range',
              style:
                  TextStyle(fontSize: 12, color: Colors.tealAccent.shade700),
            ),
          ],
        ),
      );
    }

    if (overRange) {
      return Container(
        color: Colors.orange.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 15, color: Colors.orangeAccent.shade700),
            const SizedBox(width: 8),
            Text(
              'Knee flexion exceeds recommended range',
              style: TextStyle(
                  fontSize: 12, color: Colors.orangeAccent.shade700),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

// ── Awaiting telemetry placeholder ────────────────────────────────────────────

class _AwaitingTelemetry extends StatelessWidget {
  const _AwaitingTelemetry();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 12),
          Text(
            'Awaiting telemetry...',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ── Telemetry grid ────────────────────────────────────────────────────────────

class _TelemetryGrid extends StatelessWidget {
  final Map<String, ImuFrame> frames;
  const _TelemetryGrid({required this.frames});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = frames.entries.toList();

    return Container(
      color: scheme.surface,
      child: Column(
        children: [
          _SymmetryBar(frames: frames),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.6,
              ),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final frame = entries[i].value;
                return _SensorCard(frame: frame);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sensor card ───────────────────────────────────────────────────────────────

class _SensorCard extends StatelessWidget {
  final ImuFrame frame;
  const _SensorCard({required this.frame});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final angle = frame.pitchDeg.abs();
    final isOverRange =
        (frame.sensorId == 'mixamorig_LeftLeg' ||
            frame.sensorId == 'mixamorig_RightLeg') &&
            angle > 110;

    final barColor =
        isOverRange ? Colors.orangeAccent.shade700 : scheme.primary;
    final barFraction = (angle / 150).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverRange
              ? Colors.orangeAccent.withOpacity(0.5)
              : scheme.outlineVariant,
          width: isOverRange ? 1 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _labelFor(frame.sensorId),
            style:
                TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${angle.toStringAsFixed(1)}°',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: barColor),
              ),
              Text(
                'R:${frame.rollDeg.toStringAsFixed(1)}°',
                style: TextStyle(
                    fontSize: 10, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: barFraction,
              minHeight: 3,
              backgroundColor: scheme.surface,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }

  String _labelFor(String id) {
    const labels = {
      'mixamorig_LeftLeg': 'Left knee',
      'mixamorig_RightLeg': 'Right knee',
      'mixamorig_LeftUpLeg': 'Left upper leg',
      'mixamorig_RightUpLeg': 'Right upper leg',
      'mixamorig_Hips': 'Pelvis',
      'mixamorig_Spine': 'Trunk',
      'mixamorig_LeftFoot': 'Left ankle',
      'mixamorig_RightFoot': 'Right ankle',
    };
    return labels[id] ?? id;
  }
}

// ── Symmetry bar ──────────────────────────────────────────────────────────────

class _SymmetryBar extends StatelessWidget {
  final Map<String, ImuFrame> frames;
  const _SymmetryBar({required this.frames});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    double symmetry = 0;
    final lk = frames['mixamorig_LeftLeg'];
    final rk = frames['mixamorig_RightLeg'];
    if (lk != null && rk != null) {
      final diff = (lk.pitchDeg.abs() - rk.pitchDeg.abs()).abs();
      symmetry = ((1 - diff / 90) * 100).clamp(0, 100);
    }

    Color symColor;
    if (symmetry >= 80) {
      symColor = Colors.tealAccent.shade700;
    } else if (symmetry >= 60) {
      symColor = scheme.primary;
    } else {
      symColor = Colors.orangeAccent.shade700;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Row(
        children: [
          Text('Symmetry',
              style: TextStyle(
                  fontSize: 11, color: scheme.onSurfaceVariant)),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: symmetry / 100,
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(symColor),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${symmetry.round()}%',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: symColor),
          ),
        ],
      ),
    );
  }
}

// ── App bar title ─────────────────────────────────────────────────────────────

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.accessibility_new_rounded,
            size: 20,
            color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        const Text('Orthovision',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Sensor indicator (top bar) ────────────────────────────────────────────────

class _SensorIndicator extends StatelessWidget {
  final bool connected;
  final int count;
  const _SensorIndicator({required this.connected, required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            connected
                ? Icons.sensors_rounded
                : Icons.sensors_off_rounded,
            size: 22,
            color: connected
                ? Colors.tealAccent.shade700
                : scheme.onSurfaceVariant,
          ),
          if (connected)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.shade700,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                      fontSize: 8,
                      color: Colors.black,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      onPressed: () {},
    );
  }
}

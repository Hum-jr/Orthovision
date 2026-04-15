import 'package:flutter/material.dart';
import 'imu_webview_bridge.dart';

// ── Settings View ─────────────────────────────────────────────────────────────
// Receives the live latestFrames map from the parent so it can show only
// sensors that are actually connected right now.

class SettingsView extends StatelessWidget {
  final Map<String, ImuFrame> latestFrames;

  const SettingsView({super.key, required this.latestFrames});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Section: Connected Sensors ──────────────────────────────────────
        _SectionHeader(
          icon: Icons.sensors_rounded,
          label: 'Connected Sensors',
          trailing: latestFrames.isEmpty
              ? null
              : Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${latestFrames.length} active',
                    style: TextStyle(
                        fontSize: 11, color: Colors.tealAccent.shade700),
                  ),
                ),
        ),
        const SizedBox(height: 8),

        if (latestFrames.isEmpty)
          _EmptySensorsCard()
        else
          ...latestFrames.entries
              .map((e) => _SensorConfigCard(
                    frame: e.value,
                    scheme: scheme,
                  ))
              .toList(),

        const SizedBox(height: 24),

        // ── Section: Alert Thresholds ───────────────────────────────────────
        const _SectionHeader(
          icon: Icons.tune_rounded,
          label: 'Alert Thresholds',
        ),
        const SizedBox(height: 8),
        _ThresholdCard(scheme: scheme),

        const SizedBox(height: 24),

        // ── Section: Connection ─────────────────────────────────────────────
        const _SectionHeader(
          icon: Icons.wifi_rounded,
          label: 'Connection',
        ),
        const SizedBox(height: 8),
        _ConnectionCard(scheme: scheme),

        const SizedBox(height: 24),

        // ── Section: App ────────────────────────────────────────────────────
        const _SectionHeader(
          icon: Icons.info_outline_rounded,
          label: 'About',
        ),
        const SizedBox(height: 8),
        _AboutCard(scheme: scheme),
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;

  const _SectionHeader(
      {required this.icon, required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.primary),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.3)),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ── Empty sensors card ────────────────────────────────────────────────────────

class _EmptySensorsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: scheme.outlineVariant.withOpacity(0.4), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.sensors_off_rounded,
              size: 28, color: scheme.onSurfaceVariant.withOpacity(0.5)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No sensors detected',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface)),
              const SizedBox(height: 3),
              Text('Connect the ESP32 access point\nto begin receiving data.',
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sensor config card (one per active sensor) ────────────────────────────────

class _SensorConfigCard extends StatelessWidget {
  final ImuFrame frame;
  final ColorScheme scheme;

  const _SensorConfigCard({required this.frame, required this.scheme});

  static const Map<String, String> _labels = {
    'mixamorig_LeftLeg': 'Left Knee',
    'mixamorig_RightLeg': 'Right Knee',
    'mixamorig_LeftUpLeg': 'Left Upper Leg',
    'mixamorig_RightUpLeg': 'Right Upper Leg',
    'mixamorig_Hips': 'Pelvis',
    'mixamorig_Spine': 'Trunk',
    'mixamorig_LeftFoot': 'Left Ankle',
    'mixamorig_RightFoot': 'Right Ankle',
  };

  static const Map<String, IconData> _icons = {
    'mixamorig_LeftLeg': Icons.accessibility_new_rounded,
    'mixamorig_RightLeg': Icons.accessibility_new_rounded,
    'mixamorig_LeftUpLeg': Icons.directions_walk_rounded,
    'mixamorig_RightUpLeg': Icons.directions_walk_rounded,
    'mixamorig_Hips': Icons.self_improvement_rounded,
    'mixamorig_Spine': Icons.airline_seat_recline_normal_rounded,
    'mixamorig_LeftFoot': Icons.directions_run_rounded,
    'mixamorig_RightFoot': Icons.directions_run_rounded,
  };

  String get _label => _labels[frame.sensorId] ?? frame.sensorId;
  IconData get _icon =>
      _icons[frame.sensorId] ?? Icons.sensors_rounded;

  @override
  Widget build(BuildContext context) {
    final angle = frame.pitchDeg.abs();
    final isKnee = frame.sensorId == 'mixamorig_LeftLeg' ||
        frame.sensorId == 'mixamorig_RightLeg';
    final isOver = isKnee && angle > 110;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOver
              ? Colors.orangeAccent.withOpacity(0.5)
              : scheme.outlineVariant.withOpacity(0.4),
          width: isOver ? 1 : 0.5,
        ),
      ),
      child: Row(
        children: [
          // Icon + live dot
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, size: 20, color: scheme.primary),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.shade700,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: scheme.surfaceContainerHighest, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  'ID: ${frame.sensorId}',
                  style: TextStyle(
                      fontSize: 10, color: scheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Live angle readout
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${angle.toStringAsFixed(1)}°',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isOver
                        ? Colors.orangeAccent.shade700
                        : scheme.primary),
              ),
              Text('pitch',
                  style: TextStyle(
                      fontSize: 10, color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(width: 8),
          // Status chip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isOver
                  ? Colors.orange.withOpacity(0.12)
                  : Colors.teal.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isOver ? 'Over range' : 'Normal',
              style: TextStyle(
                  fontSize: 10,
                  color: isOver
                      ? Colors.orangeAccent.shade700
                      : Colors.tealAccent.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Threshold card ────────────────────────────────────────────────────────────

class _ThresholdCard extends StatefulWidget {
  final ColorScheme scheme;
  const _ThresholdCard({required this.scheme});

  @override
  State<_ThresholdCard> createState() => _ThresholdCardState();
}

class _ThresholdCardState extends State<_ThresholdCard> {
  double _kneeThreshold = 110;

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: scheme.outlineVariant.withOpacity(0.4), width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Knee flexion alert',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('Warn above this angle',
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant)),
                ],
              ),
              Text(
                '${_kneeThreshold.round()}°',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scheme.primary),
              ),
            ],
          ),
          Slider(
            value: _kneeThreshold,
            min: 60,
            max: 150,
            divisions: 90,
            onChanged: (v) => setState(() => _kneeThreshold = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('60°',
                  style: TextStyle(
                      fontSize: 11, color: scheme.onSurfaceVariant)),
              Text('150°',
                  style: TextStyle(
                      fontSize: 11, color: scheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Connection card ───────────────────────────────────────────────────────────

class _ConnectionCard extends StatelessWidget {
  final ColorScheme scheme;
  const _ConnectionCard({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: scheme.outlineVariant.withOpacity(0.4), width: 0.5),
      ),
      child: Column(
        children: [
          _Row(
            label: 'ESP32 host',
            value: '192.168.4.1',
            scheme: scheme,
          ),
          const Divider(height: 16, thickness: 0.5),
          _Row(
            label: 'Poll interval',
            value: '200 ms',
            scheme: scheme,
          ),
          const Divider(height: 16, thickness: 0.5),
          _Row(
            label: 'Timeout',
            value: '150 ms',
            scheme: scheme,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme scheme;
  const _Row(
      {required this.label, required this.value, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
                fontFamily: 'monospace')),
      ],
    );
  }
}

// ── About card ────────────────────────────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  final ColorScheme scheme;
  const _AboutCard({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: scheme.outlineVariant.withOpacity(0.4), width: 0.5),
      ),
      child: Column(
        children: [
          _Row(label: 'App', value: 'Orthovision', scheme: scheme),
          const Divider(height: 16, thickness: 0.5),
          _Row(label: 'Version', value: '1.0.0', scheme: scheme),
          const Divider(height: 16, thickness: 0.5),
          _Row(label: 'Build', value: 'Debug', scheme: scheme),
        ],
      ),
    );
  }
}

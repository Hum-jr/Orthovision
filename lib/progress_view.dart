import 'package:flutter/material.dart';

// ── Data Models ───────────────────────────────────────────────────────────────

class SessionRecord {
  final DateTime date;
  final int durationMinutes;
  final int exercisesCompleted;
  final int totalExercises;
  final double symmetryPct;
  final double peakRomDeg;
  final String notes;

  const SessionRecord({
    required this.date,
    required this.durationMinutes,
    required this.exercisesCompleted,
    required this.totalExercises,
    required this.symmetryPct,
    required this.peakRomDeg,
    this.notes = '',
  });

  double get completionPct => exercisesCompleted / totalExercises;
  double get qualityScore => (symmetryPct * 0.5 + completionPct * 100 * 0.5);
}

class RomDataPoint {
  final String dayLabel;
  final double leftKneeDeg;
  final double rightKneeDeg;

  const RomDataPoint({
    required this.dayLabel,
    required this.leftKneeDeg,
    required this.rightKneeDeg,
  });
}

// ── Sample data ───────────────────────────────────────────────────────────────

const _romHistory = [
  RomDataPoint(dayLabel: 'M', leftKneeDeg: 58, rightKneeDeg: 95),
  RomDataPoint(dayLabel: 'T', leftKneeDeg: 65, rightKneeDeg: 97),
  RomDataPoint(dayLabel: 'W', leftKneeDeg: 72, rightKneeDeg: 96),
  RomDataPoint(dayLabel: 'T', leftKneeDeg: 78, rightKneeDeg: 98),
  RomDataPoint(dayLabel: 'F', leftKneeDeg: 82, rightKneeDeg: 99),
  RomDataPoint(dayLabel: 'S', leftKneeDeg: 91, rightKneeDeg: 100),
  RomDataPoint(dayLabel: 'T', leftKneeDeg: 127, rightKneeDeg: 101),
];

final _sessions = [
  SessionRecord(
    date: DateTime.now(),
    durationMinutes: 24,
    exercisesCompleted: 2,
    totalExercises: 5,
    symmetryPct: 74,
    peakRomDeg: 127,
    notes: 'Left knee exceeded target — monitor',
  ),
  SessionRecord(
    date: DateTime.now().subtract(const Duration(days: 3)),
    durationMinutes: 31,
    exercisesCompleted: 4,
    totalExercises: 5,
    symmetryPct: 82,
    peakRomDeg: 112,
  ),
  SessionRecord(
    date: DateTime.now().subtract(const Duration(days: 7)),
    durationMinutes: 28,
    exercisesCompleted: 4,
    totalExercises: 5,
    symmetryPct: 79,
    peakRomDeg: 108,
  ),
  SessionRecord(
    date: DateTime.now().subtract(const Duration(days: 9)),
    durationMinutes: 22,
    exercisesCompleted: 3,
    totalExercises: 5,
    symmetryPct: 61,
    peakRomDeg: 95,
  ),
  SessionRecord(
    date: DateTime.now().subtract(const Duration(days: 11)),
    durationMinutes: 18,
    exercisesCompleted: 2,
    totalExercises: 5,
    symmetryPct: 55,
    peakRomDeg: 88,
  ),
];

// ── Progress View ─────────────────────────────────────────────────────────────

class ProgressView extends StatelessWidget {
  const ProgressView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final latestSession = _sessions.first;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Summary metric cards ──
        _SectionLabel('This week'),
        const SizedBox(height: 8),
        Row(
          children: [
            _MetricCard(
              label: 'Peak ROM',
              value: '127°',
              sub: '+35° vs last week',
              icon: Icons.show_chart,
              positive: true,
            ),
            const SizedBox(width: 10),
            _MetricCard(
              label: 'Symmetry',
              value: '${latestSession.symmetryPct.round()}%',
              sub: '+8% vs last week',
              icon: Icons.compare_arrows_rounded,
              positive: true,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _MetricCard(
              label: 'Sessions',
              value: '3',
              sub: 'this week',
              icon: Icons.event_available_rounded,
              positive: true,
            ),
            const SizedBox(width: 10),
            _MetricCard(
              label: 'Avg duration',
              value: '27 min',
              sub: '+3 min vs last week',
              icon: Icons.timer_outlined,
              positive: true,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── ROM chart ──
        _SectionLabel('Knee flexion ROM — last 7 days'),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: scheme.outlineVariant, width: 0.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _LegendDot(color: scheme.primary, label: 'Left knee'),
                    const SizedBox(width: 16),
                    _LegendDot(
                        color: scheme.secondary, label: 'Right knee'),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 120,
                  child: _RomBarChart(data: _romHistory),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Symmetry timeline ──
        _SectionLabel('Symmetry index trend'),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: scheme.outlineVariant, width: 0.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _SymmetrySparkline(sessions: _sessions.reversed.toList()),
          ),
        ),
        const SizedBox(height: 20),

        // ── Session history ──
        _SectionLabel('Session history'),
        const SizedBox(height: 8),
        ..._sessions.map((s) => _SessionTile(session: s)),
      ],
    );
  }
}

// ── ROM Bar Chart ─────────────────────────────────────────────────────────────

class _RomBarChart extends StatelessWidget {
  final List<RomDataPoint> data;

  const _RomBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const maxVal = 140.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.map((pt) {
        final leftH = (pt.leftKneeDeg / maxVal).clamp(0.0, 1.0);
        final rightH = (pt.rightKneeDeg / maxVal).clamp(0.0, 1.0);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Left bar
                    Expanded(
                      child: Container(
                        height: leftH * 100,
                        decoration: BoxDecoration(
                          color: leftH > 0.85
                              ? Colors.orangeAccent.shade700
                              : scheme.primary,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 1),
                    // Right bar
                    Expanded(
                      child: Container(
                        height: rightH * 100,
                        decoration: BoxDecoration(
                          color: scheme.secondary,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(pt.dayLabel,
                    style: TextStyle(
                        fontSize: 10, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Symmetry sparkline ────────────────────────────────────────────────────────

class _SymmetrySparkline extends StatelessWidget {
  final List<SessionRecord> sessions;

  const _SymmetrySparkline({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: sessions.map((s) {
            final h = (s.symmetryPct / 100).clamp(0.0, 1.0);
            Color barColor;
            if (s.symmetryPct >= 80) {
              barColor = Colors.tealAccent.shade700;
            } else if (s.symmetryPct >= 65) {
              barColor = scheme.primary;
            } else {
              barColor = Colors.orangeAccent.shade700;
            }
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  height: h * 80,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(3)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${sessions.first.symmetryPct.round()}%',
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant)),
            Text('Latest: ${sessions.last.symmetryPct.round()}%',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary)),
          ],
        ),
      ],
    );
  }
}

// ── Session tile ──────────────────────────────────────────────────────────────

class _SessionTile extends StatelessWidget {
  final SessionRecord session;

  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final score = session.qualityScore;
    Color scoreColor;
    if (score >= 75) {
      scoreColor = Colors.tealAccent.shade700;
    } else if (score >= 55) {
      scoreColor = scheme.primary;
    } else {
      scoreColor = scheme.onSurfaceVariant;
    }

    final dayStr = _formatDate(session.date);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dayStr,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(
                    '${session.exercisesCompleted}/${session.totalExercises} exercises  ·  ${session.durationMinutes} min  ·  peak ${session.peakRomDeg.round()}°',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                  if (session.notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 11,
                            color: Colors.orangeAccent.shade700),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            session.notes,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.orangeAccent.shade700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                Text(
                  '${score.round()}%',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: scoreColor),
                ),
                Text('quality',
                    style: TextStyle(
                        fontSize: 10, color: scheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final bool positive;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(sub,
                style: TextStyle(
                    fontSize: 11,
                    color: positive
                        ? Colors.tealAccent.shade700
                        : Colors.orangeAccent.shade700)),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

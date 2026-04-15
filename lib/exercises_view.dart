import 'package:flutter/material.dart';

// ── Data Models ───────────────────────────────────────────────────────────────

enum ExerciseStatus { pending, active, complete }

class Exercise {
  final String id;
  final String name;
  final String description;
  final int totalReps;
  final int totalSets;
  final double targetRomDeg;
  final String bodyPart;
  final ExerciseStatus status;
  final int completedReps;
  final double lastRomDeg;

  const Exercise({
    required this.id,
    required this.name,
    required this.description,
    required this.totalReps,
    required this.totalSets,
    required this.targetRomDeg,
    required this.bodyPart,
    this.status = ExerciseStatus.pending,
    this.completedReps = 0,
    this.lastRomDeg = 0,
  });

  Exercise copyWith({
    ExerciseStatus? status,
    int? completedReps,
    double? lastRomDeg,
  }) =>
      Exercise(
        id: id,
        name: name,
        description: description,
        totalReps: totalReps,
        totalSets: totalSets,
        targetRomDeg: targetRomDeg,
        bodyPart: bodyPart,
        status: status ?? this.status,
        completedReps: completedReps ?? this.completedReps,
        lastRomDeg: lastRomDeg ?? this.lastRomDeg,
      );

  double get progress =>
      totalReps == 0 ? 0 : (completedReps / totalReps).clamp(0.0, 1.0);
}

// ── Exercises View ────────────────────────────────────────────────────────────

class ExercisesView extends StatefulWidget {
  const ExercisesView({super.key});

  @override
  State<ExercisesView> createState() => _ExercisesViewState();
}

class _ExercisesViewState extends State<ExercisesView> {
  final List<Exercise> _exercises = [
    const Exercise(
      id: 'knee_flex',
      name: 'Knee Flexion Reps',
      description: 'Seated knee flexion. Bend slowly to target angle, hold 2 s.',
      totalReps: 10,
      totalSets: 3,
      targetRomDeg: 90,
      bodyPart: 'Left knee',
      status: ExerciseStatus.active,
      completedReps: 6,
      lastRomDeg: 94,
    ),
    const Exercise(
      id: 'slr',
      name: 'Straight Leg Raise',
      description: 'Lying flat. Raise leg to 45° and hold for 3 s each rep.',
      totalReps: 10,
      totalSets: 2,
      targetRomDeg: 45,
      bodyPart: 'Left hip',
      status: ExerciseStatus.complete,
      completedReps: 10,
      lastRomDeg: 48,
    ),
    const Exercise(
      id: 'balance',
      name: 'Single-leg Balance',
      description: 'Stand on affected leg. Maintain for 30 s per set.',
      totalReps: 3,
      totalSets: 1,
      targetRomDeg: 0,
      bodyPart: 'Both legs',
      status: ExerciseStatus.pending,
      completedReps: 0,
      lastRomDeg: 0,
    ),
    const Exercise(
      id: 'hip_abd',
      name: 'Hip Abduction',
      description:
          'Side-lying hip abduction. Raise to 30° and return slowly.',
      totalReps: 10,
      totalSets: 3,
      targetRomDeg: 30,
      bodyPart: 'Left hip',
      status: ExerciseStatus.pending,
      completedReps: 0,
      lastRomDeg: 0,
    ),
    const Exercise(
      id: 'calf_raise',
      name: 'Calf Raises',
      description: 'Standing. Rise onto toes slowly, lower over 3 s.',
      totalReps: 15,
      totalSets: 3,
      targetRomDeg: 20,
      bodyPart: 'Ankles',
      status: ExerciseStatus.pending,
      completedReps: 0,
      lastRomDeg: 0,
    ),
  ];

  void _startExercise(String id) {
    setState(() {
      final idx = _exercises.indexWhere((e) => e.id == id);
      if (idx != -1) {
        _exercises[idx] =
            _exercises[idx].copyWith(status: ExerciseStatus.active);
      }
    });
  }

  void _addRep(String id) {
    setState(() {
      final idx = _exercises.indexWhere((e) => e.id == id);
      if (idx != -1) {
        final ex = _exercises[idx];
        final newReps = ex.completedReps + 1;
        final isDone = newReps >= ex.totalReps;
        _exercises[idx] = ex.copyWith(
          completedReps: newReps,
          status: isDone ? ExerciseStatus.complete : ExerciseStatus.active,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final completed = _exercises.where((e) => e.status == ExerciseStatus.complete).length;
    final total = _exercises.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header summary ──
        Container(
          color: scheme.surfaceContainerHighest,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Protocol',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completed of $total exercises complete',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              _SessionProgressRing(completed: completed, total: total),
            ],
          ),
        ),
        // ── Overall progress bar ──
        LinearProgressIndicator(
          value: total == 0 ? 0 : completed / total,
          minHeight: 3,
          backgroundColor: scheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
        ),
        // ── Exercise list ──
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _exercises.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _ExerciseCard(
                exercise: _exercises[index],
                onStart: () => _startExercise(_exercises[index].id),
                onAddRep: () => _addRep(_exercises[index].id),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Session progress ring ─────────────────────────────────────────────────────

class _SessionProgressRing extends StatelessWidget {
  final int completed;
  final int total;

  const _SessionProgressRing({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = total == 0 ? 0.0 : completed / total;

    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 5,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
          ),
          Center(
            child: Text(
              '$completed/$total',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Exercise Card ─────────────────────────────────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onStart;
  final VoidCallback onAddRep;

  const _ExerciseCard({
    required this.exercise,
    required this.onStart,
    required this.onAddRep,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ex = exercise;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (ex.status) {
      case ExerciseStatus.complete:
        statusColor = Colors.tealAccent.shade700;
        statusLabel = 'Complete';
        statusIcon = Icons.check_circle_rounded;
        break;
      case ExerciseStatus.active:
        statusColor = scheme.primary;
        statusLabel = 'In progress';
        statusIcon = Icons.play_circle_rounded;
        break;
      case ExerciseStatus.pending:
        statusColor = scheme.onSurfaceVariant;
        statusLabel = 'Pending';
        statusIcon = Icons.radio_button_unchecked;
        break;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: ex.status == ExerciseStatus.active
              ? scheme.primary.withOpacity(0.5)
              : scheme.outlineVariant,
          width: ex.status == ExerciseStatus.active ? 1.5 : 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card header ──
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ex.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // ── Body part tag + description ──
            Row(
              children: [
                Icon(Icons.place_outlined,
                    size: 12, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  ex.bodyPart,
                  style: TextStyle(
                      fontSize: 11, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ex.description,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),

            // ── Progress bar ──
            if (ex.totalReps > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${ex.completedReps} / ${ex.totalReps} reps  ·  ${ex.totalSets} sets',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    '${(ex.progress * 100).round()}%',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ex.progress,
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
            ],

            // ── ROM stats row (active exercises) ──
            if (ex.status == ExerciseStatus.active &&
                ex.targetRomDeg > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  _RomChip(
                    label: 'Target',
                    value: '${ex.targetRomDeg.round()}°',
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  _RomChip(
                    label: 'Current',
                    value: '${ex.lastRomDeg.round()}°',
                    color: ex.lastRomDeg >= ex.targetRomDeg
                        ? Colors.tealAccent.shade700
                        : scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  _RomChip(
                    label: 'Diff',
                    value:
                        '${(ex.lastRomDeg - ex.targetRomDeg).abs().round()}°',
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],

            // ── Action buttons ──
            if (ex.status != ExerciseStatus.complete) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  if (ex.status == ExerciseStatus.pending)
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: onStart,
                        child: const Text('Start exercise'),
                      ),
                    ),
                  if (ex.status == ExerciseStatus.active) ...[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onAddRep,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Log rep'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {},
                      child: const Text('Pause'),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── ROM chip ──────────────────────────────────────────────────────────────────

class _RomChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _RomChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

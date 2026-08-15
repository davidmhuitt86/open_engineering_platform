import 'dart:async';

import 'package:flutter/material.dart';
import 'package:engineering_engine/engineering_engine.dart';

import '../../core/theme/studio_colors.dart';
import '../../engineering_intelligence/widgets/ei_widgets.dart';
import 'diagram_simulation_service.dart';

/// AP-DS-005 Interactive Simulation controls — Play/Pause/Resume/Reset/
/// Step/Timeline (scrubbable)/Bookmarks/Replay/Speed. Every control's
/// enabled/disabled state and current position is read directly from
/// [DiagramSimulationService.currentSession] (real `SimulationSession`
/// data) on every rebuild — no independently-tracked local playback
/// position/paused flag that could drift from engine truth. The one
/// piece of genuinely local UI state is [_speed] (the playback speed
/// multiplier), which only controls the `stepDelay` passed to
/// `SimulationEngine.play` — it is not itself simulated state.
class SimulationPlaybackControls extends StatefulWidget {
  const SimulationPlaybackControls({super.key, required this.simulation, required this.onChanged});

  final DiagramSimulationService simulation;

  /// Invoked after any action that changes session state, so the host
  /// dialog can rebuild dependents (diagnostics/overlay/power panels).
  final VoidCallback onChanged;

  @override
  State<SimulationPlaybackControls> createState() => _SimulationPlaybackControlsState();
}

class _SimulationPlaybackControlsState extends State<SimulationPlaybackControls> {
  double _speed = 1.0;
  StreamSubscription<SimulationStateSnapshot>? _playSub;
  bool _playing = false;
  String? _error;
  final TextEditingController _bookmarkLabelController = TextEditingController();

  @override
  void dispose() {
    _playSub?.cancel();
    _bookmarkLabelController.dispose();
    super.dispose();
  }

  Duration get _stepDelay => Duration(milliseconds: (400 / _speed).round());

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _error = null);
    try {
      await action();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() {});
        widget.onChanged();
      }
    }
  }

  void _play() {
    if (_playing) return;
    setState(() => _playing = true);
    _playSub = widget.simulation.play(stepDelay: _stepDelay).listen(
      (_) {
        if (mounted) {
          setState(() {});
          widget.onChanged();
        }
      },
      onDone: () {
        if (mounted) {
          setState(() => _playing = false);
          widget.onChanged();
        }
      },
      onError: (Object e) {
        if (mounted) setState(() => _error = '$e');
      },
    );
  }

  void _pausePlayback() {
    _playSub?.cancel();
    _playSub = null;
    setState(() => _playing = false);
    _run(widget.simulation.pause);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.simulation.currentSession;
    final hasSession = session != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) EiErrorBanner(message: _error!),
          if (!hasSession)
            const EiEmptyState(icon: Icons.play_disabled_outlined, message: 'No simulation session yet. Create one from the Sessions tab.')
          else ...[
            Row(
              children: [
                EiChip(session.isPaused ? 'Paused' : (_playing ? 'Playing' : 'Idle'), color: _playing ? StudioColors.success : StudioColors.inactive),
                const SizedBox(width: 8),
                Text('Position ${session.playbackPosition} / ${session.history.length}', style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11.5)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  key: const Key('sim_play'),
                  onPressed: _playing ? null : _play,
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Play'),
                ),
                ElevatedButton.icon(
                  key: const Key('sim_pause'),
                  onPressed: !_playing ? null : _pausePlayback,
                  icon: const Icon(Icons.pause, size: 16),
                  label: const Text('Pause'),
                ),
                ElevatedButton.icon(
                  key: const Key('sim_resume'),
                  onPressed: !session.isPaused ? null : () => _run(widget.simulation.resume),
                  icon: const Icon(Icons.play_circle_outline, size: 16),
                  label: const Text('Resume'),
                ),
                ElevatedButton.icon(
                  key: const Key('sim_step'),
                  onPressed: () => _run(widget.simulation.step),
                  icon: const Icon(Icons.skip_next, size: 16),
                  label: const Text('Step'),
                ),
                ElevatedButton.icon(
                  key: const Key('sim_reset'),
                  onPressed: () => _run(widget.simulation.reset),
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: const Text('Reset'),
                ),
                ElevatedButton.icon(
                  key: const Key('sim_replay'),
                  onPressed: () => _run(() => widget.simulation.replay()),
                  icon: const Icon(Icons.replay, size: 16),
                  label: const Text('Replay'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Timeline', style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
            Slider(
              key: const Key('sim_timeline_slider'),
              value: session.playbackPosition.toDouble().clamp(0, session.history.length.toDouble()),
              min: 0,
              max: session.history.length.toDouble() == 0 ? 1 : session.history.length.toDouble(),
              divisions: session.history.isEmpty ? null : session.history.length,
              label: '${session.playbackPosition}',
              onChanged: session.history.isEmpty
                  ? null
                  : (value) {
                      final target = value.round();
                      final current = session.playbackPosition;
                      final steps = target - current;
                      if (steps == 0) return;
                      _run(() async {
                        if (steps > 0) {
                          for (var i = 0; i < steps; i++) {
                            await widget.simulation.step();
                          }
                        } else {
                          await widget.simulation.reset();
                          for (var i = 0; i < target; i++) {
                            await widget.simulation.step();
                          }
                        }
                      });
                    },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Speed', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11.5)),
                Expanded(
                  child: Slider(
                    key: const Key('sim_speed_slider'),
                    value: _speed,
                    min: 0.25,
                    max: 4.0,
                    divisions: 15,
                    label: '${_speed.toStringAsFixed(2)}x',
                    onChanged: (v) => setState(() => _speed = v),
                  ),
                ),
              ],
            ),
            const Divider(color: StudioColors.borderSubtle),
            Text('Bookmarks (${session.bookmarks.length})', style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('sim_bookmark_label_field'),
                    controller: _bookmarkLabelController,
                    style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12),
                    decoration: const InputDecoration(hintText: 'Bookmark label', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  key: const Key('sim_add_bookmark'),
                  onPressed: _bookmarkLabelController.text.trim().isEmpty
                      ? null
                      : () => _run(() => widget.simulation.addBookmark(_bookmarkLabelController.text.trim())),
                  child: const Text('Add'),
                ),
              ],
            ),
            for (final bookmark in session.bookmarks)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(bookmark.label, style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12)),
                subtitle: Text('Position ${bookmark.position}', style: const TextStyle(color: StudioColors.textSecondary, fontSize: 10.5)),
                trailing: IconButton(
                  tooltip: 'Jump to bookmark',
                  icon: const Icon(Icons.bookmark, size: 16),
                  onPressed: () => _run(() => widget.simulation.jumpToBookmark(bookmark.label)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

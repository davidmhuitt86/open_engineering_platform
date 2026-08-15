import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/studio_colors.dart';
import '../core/engineering_instrument.dart';
import 'multimeter_controller.dart';

/// WP-DS-005A Digital Multimeter panel — mode selector, measurement type
/// selector (with `capacitance`/`temperature` shown disabled as
/// "not yet supported", per the spec's own named future placeholders),
/// probe status, Measure action, and the full result readout (measured/
/// expected/difference/path/power/ground/contributing relationships/
/// timestamp).
class DigitalMultimeterInstrument extends EngineeringInstrument {
  const DigitalMultimeterInstrument({required this.controller, this.verificationReport});

  final MultimeterController controller;

  /// Optional: supplied by the host page from its own last
  /// `DiagramSimulationService.verify()` call, so the panel can show
  /// related Verification findings (light-touch Engineering Integration).
  final VerificationReport? Function()? verificationReport;

  @override
  String get id => 'digital_multimeter';

  @override
  String get title => 'Multimeter';

  @override
  IconData get icon => Icons.speed_outlined;

  @override
  String? get shortcutLabel => 'Ctrl+M';

  @override
  Widget buildPanel(BuildContext context) => DigitalMultimeterPanel(
        controller: controller,
        verificationReport: verificationReport,
      );
}

class DigitalMultimeterPanel extends StatelessWidget {
  const DigitalMultimeterPanel({super.key, required this.controller, this.verificationReport});

  final MultimeterController controller;
  final VerificationReport? Function()? verificationReport;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 260, child: _Controls(controller: controller)),
          const SizedBox(width: 12),
          Expanded(child: _Result(controller: controller, verificationReport: verificationReport)),
        ],
      ),
    );
  }
}

/// `node-id` alone, or `node-id (portId)` when the probe is snapped to a
/// specific port (e.g. a battery's `positive`/`negative` terminal) rather
/// than the node as a whole -- see `ProbeOverlay`'s own doc comment.
String _probeLabel(ProbePoint? point) {
  if (point == null) return '—';
  return point.portId == null ? point.nodeId : '${point.nodeId} (${point.portId})';
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller});

  final MultimeterController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Measurement type', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          DropdownButton<MeasurementType>(
            isExpanded: true,
            value: controller.selectedType,
            dropdownColor: StudioColors.surfaceRaised,
            style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12),
            items: [
              for (final type in MeasurementType.values)
                DropdownMenuItem(
                  value: type,
                  enabled: !unsupportedMeasurementTypes.contains(type),
                  child: Text(
                    unsupportedMeasurementTypes.contains(type) ? '${type.name} (not yet supported)' : type.name,
                    style: TextStyle(
                      color: unsupportedMeasurementTypes.contains(type)
                          ? StudioColors.textDisabled
                          : StudioColors.textPrimary,
                    ),
                  ),
                ),
            ],
            onChanged: (t) => t == null ? null : controller.setType(t),
          ),
          const SizedBox(height: 12),
          const Text('Mode', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          DropdownButton<MeasurementMode>(
            isExpanded: true,
            value: controller.selectedMode,
            dropdownColor: StudioColors.surfaceRaised,
            style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12),
            items: [
              for (final mode in MeasurementMode.values)
                DropdownMenuItem(value: mode, child: Text(mode.name)),
            ],
            onChanged: (m) => m == null ? null : controller.setMode(m),
          ),
          const SizedBox(height: 8),
          Text('Probe A (black): ${_probeLabel(controller.probeA)}',
              style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
          Text('Probe B (red): ${_probeLabel(controller.probeB)}',
              style: const TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: controller.canMeasure ? controller.measure : null,
                child: Text(controller.busy ? 'Measuring…' : 'Measure'),
              ),
              const SizedBox(width: 8),
              if (controller.isLiveMode)
                ElevatedButton(
                  onPressed: () => controller.liveActive ? controller.stopLive() : controller.startLive(),
                  child: Text(controller.liveActive ? 'Stop' : 'Start live'),
                ),
            ],
          ),
          if (controller.lastError != null) ...[
            const SizedBox(height: 8),
            Text(controller.lastError!, style: const TextStyle(color: StudioColors.error, fontSize: 11)),
          ],
          if (controller.selectedMode == MeasurementMode.historical) ...[
            const SizedBox(height: 12),
            const Text('Compare against', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
            DropdownButton<String>(
              isExpanded: true,
              value: controller.historicalCompareEntryId,
              dropdownColor: StudioColors.surfaceRaised,
              hint: const Text('Select history entry', style: TextStyle(fontSize: 11, color: StudioColors.textSecondary)),
              items: [
                for (final e in controller.history)
                  DropdownMenuItem(
                    value: e.id,
                    child: Text(
                      '${e.result.type.name} @ ${e.result.timestamp.toIso8601String()}',
                      style: const TextStyle(fontSize: 11, color: StudioColors.textPrimary),
                    ),
                  ),
              ],
              onChanged: controller.setHistoricalCompareEntry,
            ),
            if (controller.historicalDifference != null)
              Text('Δ vs. history: ${controller.historicalDifference}',
                  style: const TextStyle(color: StudioColors.textPrimary, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.controller, this.verificationReport});

  final MultimeterController controller;
  final VerificationReport? Function()? verificationReport;

  @override
  Widget build(BuildContext context) {
    final result = controller.latestResult;
    if (result == null) {
      return const Center(
        child: Text('No measurement yet.', style: TextStyle(color: StudioColors.textSecondary, fontSize: 12)),
      );
    }
    final related = controller.relatedFindings(verificationReport?.call());
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Reachable', result.reachable.toString()),
          if (result.continuous != null) _row('Continuity', result.continuous! ? 'Closed (continuity)' : 'Open circuit'),
          _row('Measured', result.measuredValue == null ? '—' : '${result.measuredValue} ${result.unit}'),
          _row('Expected', result.expectedValue == null ? '—' : '${result.expectedValue} ${result.unit}'),
          _row('Difference', result.difference == null ? '—' : '${result.difference} ${result.unit}'),
          _row('Path', result.path.isEmpty ? '—' : result.path.join(' → ')),
          _row('Power source', result.powerSourceId ?? '—'),
          _row('Ground source', result.groundSourceId ?? '—'),
          _row('Contributing relationships',
              result.contributingRelationshipIds.isEmpty ? '—' : result.contributingRelationshipIds.join(', ')),
          _row('Timestamp', result.timestamp.toIso8601String()),
          _row('Mode', result.mode.name),
          if (result.notes != null) _row('Notes', result.notes!),
          if (related.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Related verification findings', style: TextStyle(color: StudioColors.textSecondary, fontSize: 11)),
            for (final f in related)
              Text('• ${f.severity.name}: ${f.message}', style: const TextStyle(color: StudioColors.warning, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 12, color: StudioColors.textPrimary),
            children: [
              TextSpan(text: '$label: ', style: const TextStyle(color: StudioColors.textSecondary)),
              TextSpan(text: value),
            ],
          ),
        ),
      );
}

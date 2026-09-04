import 'package:engineering_engine/engineering_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/studio_colors.dart';
import 'analysis_controller.dart';
import 'analysis_ui_state.dart';

/// AP-EK-020 Part B — Diagram Studio's presentation of an
/// [AnalysisResult]. This widget is a pure consumer: every value it
/// renders is read directly off [AnalysisUiState.result] (produced by
/// [AnalysisEngine] and reached only through [AnalysisNotifier.analyze]).
/// It performs no engineering computation of its own — no `/`, `*`, or
/// comparison operator here ever combines two engineering quantities;
/// the only arithmetic in this file is string/layout formatting.
class AnalysisResultsPanel extends ConsumerWidget {
  final String instanceId;

  const AnalysisResultsPanel({super.key, required this.instanceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uiState = ref.watch(diagramAnalysisFamily(instanceId));

    return Material(
      color: StudioColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(instanceId: instanceId, uiState: uiState),
          if (uiState.isStale) const _StaleBanner(),
          Expanded(child: _Body(uiState: uiState)),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  final String instanceId;
  final AnalysisUiState uiState;

  const _Header({required this.instanceId, required this.uiState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyzing = uiState.phase == AnalysisUiPhase.analyzing;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: StudioColors.surfaceSunken,
        border: Border(bottom: BorderSide(color: StudioColors.border)),
      ),
      child: Row(
        children: [
          const Text('Analysis',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const Spacer(),
          SizedBox(
            height: 26,
            child: ElevatedButton(
              onPressed: analyzing
                  ? null
                  : () => ref
                      .read(diagramAnalysisFamily(instanceId).notifier)
                      .analyze(),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: Text(analyzing ? 'Analyzing…' : 'Analyze'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: const Color(0xFF3A2E12),
      child: const Text(
        'Historical — the diagram has changed since this analysis ran. Analyze again for a current result.',
        style: TextStyle(fontSize: 11, color: Color(0xFFE0B84A)),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final AnalysisUiState uiState;

  const _Body({required this.uiState});

  @override
  Widget build(BuildContext context) {
    if (uiState.phase == AnalysisUiPhase.idle && uiState.result == null) {
      return const _EmptyState();
    }
    if (uiState.phase == AnalysisUiPhase.failure && uiState.result == null) {
      return _MessageState(
          text: uiState.errorMessage ?? 'Analysis failed.', isError: true);
    }
    final result = uiState.result;
    if (result == null) {
      return const _MessageState(text: 'Analyzing…', isError: false);
    }
    if (result.status != AnalysisStatus.success) {
      return _FailureView(result: result, explanation: uiState.explanation);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummarySection(result: result),
          const SizedBox(height: 16),
          _ComponentResultsSection(result: result),
          const SizedBox(height: 16),
          _ConstraintsSection(result: result),
          if (result.diagnostics.isNotEmpty) ...[
            const SizedBox(height: 16),
            _DiagnosticsSection(result: result),
          ],
          const SizedBox(height: 16),
          _DerivationSection(result: result),
          const SizedBox(height: 16),
          _ProvenanceSection(result: result),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Click Analyze to run electrical analysis on the current diagram.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: StudioColors.textSecondary),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final String text;
  final bool isError;

  const _MessageState({required this.text, required this.isError});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 12,
              color: isError ? Colors.redAccent : StudioColors.textSecondary),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: StudioColors.textSecondary,
        ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  final AnalysisResult result;

  const _SummarySection({required this.result});

  @override
  Widget build(BuildContext context) {
    ComponentResult? firstWhereOrNull(bool Function(ComponentResult) test) {
      for (final component in result.componentResults) {
        if (test(component)) return component;
      }
      return null;
    }

    final source = firstWhereOrNull((c) => c.quantities.containsKey('voltage'));
    final resistor =
        firstWhereOrNull((c) => c.quantities.containsKey('resistance'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Summary'),
        const Text(
          'Analysis: Successful',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4ADE80)),
        ),
        const SizedBox(height: 8),
        if (source != null)
          _detailRow('Source Voltage',
              _formatQuantity(source.quantities['voltage'], 'V')),
        if (resistor != null)
          _detailRow('Resistance',
              _formatQuantity(resistor.quantities['resistance'], 'Ω')),
        _detailRow('Current', _formatQuantity(result.current, 'A')),
        _detailRow('Resistor Power', _formatQuantity(result.power, 'W')),
      ],
    );
  }
}

class _ComponentResultsSection extends StatelessWidget {
  final AnalysisResult result;

  const _ComponentResultsSection({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Component Results'),
        for (final component in result.componentResults) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(component.sourceObjectId,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          for (final entry in component.quantities.entries)
            _detailRow(
              _titleCase(entry.key),
              _formatQuantity(entry.value,
                  _unitSymbolFor(component.quantityUnitIds[entry.key])),
            ),
          const SizedBox(height: 8),
        ],
        if (result.nodeResults.isNotEmpty) ...[
          const SizedBox(height: 4),
          const Text('Node Voltages',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          for (final node in result.nodeResults)
            _detailRow(node.nodeId, _formatQuantity(node.voltage, 'V')),
        ],
      ],
    );
  }
}

class _ConstraintsSection extends StatelessWidget {
  final AnalysisResult result;

  const _ConstraintsSection({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Constraints'),
        for (final constraint in result.constraintResults)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  constraint.satisfied ? Icons.check_circle : Icons.error,
                  size: 14,
                  color: constraint.satisfied
                      ? const Color(0xFF4ADE80)
                      : Colors.redAccent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${constraint.subject}  —  ${constraint.satisfied ? "SATISFIED" : "VIOLATED"}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DiagnosticsSection extends StatelessWidget {
  final AnalysisResult result;

  const _DiagnosticsSection({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Diagnostics'),
        for (final diagnostic in result.diagnostics)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '[${diagnostic.severity.name}] ${diagnostic.message}',
              style: const TextStyle(
                  fontSize: 11, color: StudioColors.textSecondary),
            ),
          ),
      ],
    );
  }
}

class _DerivationSection extends StatelessWidget {
  final AnalysisResult result;

  const _DerivationSection({required this.result});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const _SectionLabel('Derivation'),
      initiallyExpanded: true,
      children: [
        for (final step in result.derivation)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${step.stepNumber}. ${step.description}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                if (step.equationExpression != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 2),
                    child: Text(step.equationExpression!,
                        style: const TextStyle(
                            fontSize: 11.5, fontFamily: 'monospace')),
                  ),
                if (step.output != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 2),
                    child: Text(
                      '${step.output!['name']} = ${step.output!['value']} ${_unitSymbolFor(step.output!['unitId'] as String?)}',
                      style: const TextStyle(
                          fontSize: 11.5, fontFamily: 'monospace'),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ProvenanceSection extends StatelessWidget {
  final AnalysisResult result;

  const _ProvenanceSection({required this.result});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const _SectionLabel('Provenance'),
      children: [
        for (final entry in result.provenance)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.subject,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                if (entry.sourceObjectId != null)
                  _detailRow('Engineering Object', entry.sourceObjectId!),
                if (entry.componentModelId != null)
                  _detailRow('Model',
                      '${entry.componentModelId} v${entry.componentModelVersion}'),
                if (entry.lawId != null)
                  _detailRow('Law', '${entry.lawId} v${entry.lawVersion}'),
                if (entry.equationId != null)
                  _detailRow('Equation',
                      '${entry.equationId} v${entry.equationVersion}'),
                _detailRow('Knowledge Package',
                    '${entry.knowledgePackageId} v${entry.knowledgePackageVersion}'),
                _detailRow('Runtime', entry.runtimeVersion),
              ],
            ),
          ),
      ],
    );
  }
}

class _FailureView extends StatelessWidget {
  final AnalysisResult result;
  final Explanation? explanation;

  const _FailureView({required this.result, required this.explanation});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analysis: ${_statusLabel(result.status)}',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.redAccent),
          ),
          const SizedBox(height: 8),
          for (final diagnostic in result.diagnostics)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(diagnostic.message,
                  style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

Widget _detailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: StudioColors.textSecondary),
          ),
        ),
        Text(value,
            style:
                const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

String _formatQuantity(double? value, String unitSymbol) {
  if (value == null) return '—';
  final rounded = (value * 1e9).round() / 1e9;
  var text = rounded.toString();
  if (text.contains('.')) {
    text =
        text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return '$text $unitSymbol';
}

String _unitSymbolFor(String? unitId) {
  switch (unitId) {
    case 'unit.volt':
      return 'V';
    case 'unit.ampere':
      return 'A';
    case 'unit.ohm':
      return 'Ω';
    case 'unit.watt':
      return 'W';
    default:
      return '';
  }
}

String _titleCase(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

String _statusLabel(AnalysisStatus status) {
  switch (status) {
    case AnalysisStatus.insufficientData:
      return 'Insufficient Data';
    case AnalysisStatus.invalidInput:
      return 'Invalid Input';
    case AnalysisStatus.unsupported:
      return 'Unsupported';
    case AnalysisStatus.singular:
      return 'Singular System';
    case AnalysisStatus.nonConvergent:
      return 'Non-Convergent';
    case AnalysisStatus.inconsistent:
      return 'Inconsistent';
    case AnalysisStatus.failed:
      return 'Failed';
    case AnalysisStatus.partial:
      return 'Partial';
    case AnalysisStatus.stale:
      return 'Stale';
    case AnalysisStatus.success:
      return 'Successful';
  }
}

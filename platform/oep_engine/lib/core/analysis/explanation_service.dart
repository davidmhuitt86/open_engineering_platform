import 'models/analysis_result.dart';

/// AP-EK-020 Phase 18/§28 — turns an [AnalysisResult]'s structured
/// derivation into prose. Consumes the result only; never recomputes an
/// engineering value (every number below is read from
/// [AnalysisResult.derivation]/`componentResults`, not from a fresh
/// division/multiplication).
class Explanation {
  final String summary;
  final List<String> lines;

  const Explanation(this.summary, this.lines);

  String get text => ([summary, ...lines]).join('\n');
}

class ExplanationService {
  const ExplanationService();

  Explanation explain(AnalysisResult result) {
    if (result.status != AnalysisStatus.success) {
      return _explainFailure(result);
    }

    final lines = <String>[];
    for (final step in result.derivation) {
      final output = step.output;
      if (output == null) {
        final expression = step.equationExpression;
        lines.add(
          expression == null
              ? '${step.stepNumber}. ${step.description}'
              : '${step.stepNumber}. ${step.description} $expression',
        );
        continue;
      }
      final name = output['name'];
      final value = _format(output['value'] as num);
      final unitId = output['unitId'] as String?;
      final unitSymbol = _symbolFor(unitId);
      lines.add(
        '${step.stepNumber}. ${step.description} $name = $value$unitSymbol',
      );
    }

    final current = result.current;
    final power = result.power;
    final summary = current != null && power != null
        ? 'A source is connected through a resistor to the reference node. '
              'Using Ohm\'s law, the current is ${_format(current)}A; the resistor dissipates ${_format(power)}W.'
        : 'Analysis completed.';

    return Explanation(summary, lines);
  }

  Explanation _explainFailure(AnalysisResult result) {
    if (result.diagnostics.isEmpty) {
      return Explanation(
        'Analysis did not complete successfully (${result.status.name}).',
        const [],
      );
    }
    final lines = result.diagnostics.map((d) => '- ${d.message}').toList();
    return Explanation(
      'Analysis did not complete successfully (${result.status.name}):',
      lines,
    );
  }

  /// Display-only rounding consistent with the `ieee754-double-1e-9`
  /// numeric policy — collapses binary floating-point representation
  /// noise (e.g. `14.399999999999999`) to the value it is within policy
  /// tolerance of (`14.4`) for human-readable prose. [AnalysisResult]'s
  /// own stored numeric fields are never touched by this — only prose
  /// output goes through it.
  String _format(num value) {
    final rounded = (value * 1e9).round() / 1e9;
    var text = rounded.toString();
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '');
      text = text.replaceFirst(RegExp(r'\.$'), '');
    }
    return text;
  }

  String _symbolFor(String? unitId) {
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
}

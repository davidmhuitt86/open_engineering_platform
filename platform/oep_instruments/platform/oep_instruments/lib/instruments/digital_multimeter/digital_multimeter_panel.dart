// `showDialog`/`Material`/`MaterialType` only (the "More" mode picker's
// routing plumbing) -- deliberately not `package:flutter/material.dart`'s
// full surface, and no Material Icons font is used anywhere in this file,
// consistent with this package's `uses-material-design: false` pubspec
// declaration.
import 'package:flutter/material.dart' show Material, MaterialType, showDialog;
import 'package:flutter/widgets.dart';

import '../../measurement/measurement.dart';
import '../../measurement/measurement_state.dart';
import 'digital_multimeter_plugin.dart';
import 'dmm_measurement_mode.dart';
import 'dmm_probe_jack.dart';

/// OIP-DS-001 — the Digital Multimeter panel, built to match the premium
/// bezel-and-console reference design (bezel header, mode tab strip,
/// main display card with REL/HOLD/bargraph, TREND/MIN-MAX/RECORD row,
/// info chip row, bottom navigation, rotary control cluster, and probe
/// jack row).
///
/// **Disclosed scope**: HOLD, REL, and MIN/MAX are real, wired to
/// [DigitalMultimeterPlugin]'s own state — everything else visual in the
/// reference design that this first increment doesn't yet have real
/// behavior for (auto-ranging, TREND/graphing, RECORD, SAVE, FUNC, the
/// Measure/Graph/Data/Settings bottom-nav destinations, real battery/
/// Bluetooth-radio status) is rendered faithfully but is cosmetic —
/// tapping it shows an honest "not yet available" affordance rather than
/// silently doing nothing or fabricating behavior. No Material/Cupertino
/// icon fonts are used (this package declares `uses-material-design:
/// false`, matching the Runtime's platform-independence principle) —
/// every glyph below is plain text/Unicode or drawn with [CustomPaint].
class DigitalMultimeterPanel extends StatefulWidget {
  const DigitalMultimeterPanel({super.key, required this.plugin});

  final DigitalMultimeterPlugin plugin;

  @override
  State<DigitalMultimeterPanel> createState() => _DigitalMultimeterPanelState();
}

class _DigitalMultimeterPanelState extends State<DigitalMultimeterPanel> {
  static const List<DmmMeasurementMode> _primaryModes = [
    DmmMeasurementMode.dcVoltage,
    DmmMeasurementMode.acVoltage,
    DmmMeasurementMode.resistance,
    DmmMeasurementMode.continuity,
    DmmMeasurementMode.diode,
  ];

  static const List<DmmMeasurementMode> _moreModes = [
    DmmMeasurementMode.current,
    DmmMeasurementMode.frequency,
    DmmMeasurementMode.dutyCycle,
    DmmMeasurementMode.temperature,
    DmmMeasurementMode.capacitance,
  ];

  static const Map<DmmMeasurementMode, String> _modeSymbols = {
    DmmMeasurementMode.dcVoltage: 'V⎓',
    DmmMeasurementMode.acVoltage: 'V~',
    DmmMeasurementMode.resistance: 'Ω',
    DmmMeasurementMode.continuity: '•)))',
    DmmMeasurementMode.diode: '-|>|-',
    DmmMeasurementMode.current: 'A',
    DmmMeasurementMode.frequency: 'Hz',
    DmmMeasurementMode.dutyCycle: '%',
    DmmMeasurementMode.temperature: '°C',
    DmmMeasurementMode.capacitance: 'F',
  };

  static const Map<DmmMeasurementMode, String> _modeTitles = {
    DmmMeasurementMode.dcVoltage: 'DC Voltage',
    DmmMeasurementMode.acVoltage: 'AC Voltage',
    DmmMeasurementMode.resistance: 'Resistance',
    DmmMeasurementMode.continuity: 'Continuity',
    DmmMeasurementMode.diode: 'Diode',
    DmmMeasurementMode.current: 'Current',
    DmmMeasurementMode.frequency: 'Frequency',
    DmmMeasurementMode.dutyCycle: 'Duty Cycle',
    DmmMeasurementMode.temperature: 'Temperature',
    DmmMeasurementMode.capacitance: 'Capacitance',
  };

  DigitalMultimeterPlugin get plugin => widget.plugin;

  String? _toast;

  void _showNotYetAvailable(String feature) {
    setState(() => _toast = '$feature — not yet available');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _toast == '$feature — not yet available') setState(() => _toast = null);
    });
  }

  void _selectMode(DmmMeasurementMode mode) {
    plugin.setMode(mode);
    plugin.requestMeasurement();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: plugin.revision,
      builder: (context, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF06070A),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF1B1E24), width: 10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: DecoratedBox(
              decoration: const BoxDecoration(color: Color(0xFF0B0D11)),
              child: Column(
                children: [
                  const _BezelHeader(),
                  _StatusBar(connected: plugin.isConnected),
                  // The full instrument face (mode tabs through the footer
                  // tagline) is taller than many real phone viewports at
                  // once -- scrollable rather than fixed-height, so it
                  // degrades gracefully on a small screen instead of
                  // overflowing (the reference design assumes a single
                  // tall screen; this keeps the same content usable on a
                  // shorter one too).
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        _ModeTabStrip(
                          primaryModes: _primaryModes,
                          moreModes: _moreModes,
                          symbols: _modeSymbols,
                          titles: _modeTitles,
                          current: plugin.mode,
                          onSelect: _selectMode,
                        ),
                        const SizedBox(height: 10),
                        _MainDisplayCard(
                          title: _modeTitles[plugin.mode]!,
                          symbol: _modeSymbols[plugin.mode]!,
                          measurement: plugin.displayedMeasurement,
                          relativeValue: plugin.relativeValue,
                          isRelativeActive: plugin.isRelativeActive,
                          isHeld: plugin.isHeld,
                          jackWarning: !plugin.isJackCorrectForMode,
                        ),
                        const SizedBox(height: 10),
                        _SecondaryButtonRow(
                          onTrend: () => _showNotYetAvailable('Trend'),
                          onMinMax: () => _showMinMax(context),
                          onRecord: () => _showNotYetAvailable('Record'),
                        ),
                        const SizedBox(height: 10),
                        const _InfoChipRow(),
                        const SizedBox(height: 10),
                        _BottomNavBar(onNonHomeTap: _showNotYetAvailable),
                        const SizedBox(height: 12),
                        _RotaryCluster(
                          isHeld: plugin.isHeld,
                          isRelativeActive: plugin.isRelativeActive,
                          onRel: () {
                            plugin.toggleRelative();
                          },
                          onHold: plugin.toggleHold,
                          onZero: () {
                            plugin.toggleRelative();
                          },
                          onMaxMin: () => _showMinMax(context),
                          onSave: () => _showNotYetAvailable('Save'),
                          onFunc: () => _showNotYetAvailable('Func'),
                        ),
                        const SizedBox(height: 14),
                        _ProbeJackRow(
                          current: plugin.redJack,
                          onSelect: (jack) {
                            plugin.setRedJack(jack);
                            plugin.requestMeasurement();
                          },
                        ),
                        const SizedBox(height: 10),
                        if (_toast != null) _ToastBanner(text: _toast!),
                        const SizedBox(height: 8),
                        const _FooterTagline(),
                        const SizedBox(height: 10),
                      ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMinMax(BuildContext context) {
    setState(() {
      final min = plugin.minValue;
      final max = plugin.maxValue;
      _toast = (min == null || max == null) ? 'No Min/Max captured yet' : 'MIN ${min.toStringAsFixed(3)}  •  MAX ${max.toStringAsFixed(3)}';
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
  }
}

class _BezelHeader extends StatelessWidget {
  const _BezelHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('O', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2)),
              Text('E', style: TextStyle(color: Color(0xFFE6E9EE), fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2)),
              Text('P', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2)),
            ],
          ),
          const SizedBox(height: 2),
          const Text('OPEN ENGINEERING PLATFORM', style: TextStyle(color: Color(0xFF5B6572), fontSize: 9, letterSpacing: 2)),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFF0F1216),
      child: Row(
        children: [
          Text(now.text, style: const TextStyle(color: Color(0xFF9AA5B1), fontSize: 11)),
          const Spacer(),
          const Text('DMM', style: TextStyle(color: Color(0xFFE6E9EE), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const Spacer(),
          Text(
            connected ? '●' : '○',
            style: TextStyle(color: connected ? const Color(0xFF3B82F6) : const Color(0xFF5B6572), fontSize: 12),
          ),
          const SizedBox(width: 8),
          // Real battery telemetry is a disclosed follow-up -- this is a
          // static, honest placeholder, not a fabricated live reading.
          const Text('- -%', style: TextStyle(color: Color(0xFF5B6572), fontSize: 11)),
        ],
      ),
    );
  }
}

/// A tiny, dependency-free `TimeOfDay`-alike (this package has no
/// Material dependency, so `TimeOfDay` itself isn't available) —
/// formats the real device clock, matching the reference design's
/// status-bar clock.
class TimeOfDay {
  const TimeOfDay._(this.text);
  final String text;
  factory TimeOfDay.now() {
    final now = DateTime.now();
    final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return TimeOfDay._('$hour12:$minute $period');
  }
}

class _ModeTabStrip extends StatelessWidget {
  const _ModeTabStrip({
    required this.primaryModes,
    required this.moreModes,
    required this.symbols,
    required this.titles,
    required this.current,
    required this.onSelect,
  });

  final List<DmmMeasurementMode> primaryModes;
  final List<DmmMeasurementMode> moreModes;
  final Map<DmmMeasurementMode, String> symbols;
  final Map<DmmMeasurementMode, String> titles;
  final DmmMeasurementMode current;
  final ValueChanged<DmmMeasurementMode> onSelect;

  @override
  Widget build(BuildContext context) {
    final moreActive = moreModes.contains(current);
    return SizedBox(
      height: 68,
      child: Row(
        children: [
          for (final mode in primaryModes)
            Expanded(
              child: _ModeTab(
                symbol: symbols[mode]!,
                title: titles[mode]!,
                selected: mode == current,
                onTap: () => onSelect(mode),
              ),
            ),
          Expanded(
            child: _ModeTab(
              symbol: '•••',
              title: moreActive ? titles[current]! : 'More',
              selected: moreActive,
              onTap: () => _showMorePicker(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMorePicker(BuildContext context) async {
    final selected = await showDialog<DmmMeasurementMode>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Center(
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF161C25), borderRadius: BorderRadius.circular(8)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final mode in moreModes)
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(mode),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Row(
                        children: [
                          Text(symbols[mode]!, style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 14)),
                          const SizedBox(width: 10),
                          Text(titles[mode]!, style: const TextStyle(color: Color(0xFFE6E9EE), fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected != null) onSelect(selected);
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({required this.symbol, required this.title, required this.selected, required this.onTap});

  final String symbol;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3B82F6) : const Color(0xFF161C25),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? const Color(0xFF60A5FA) : const Color(0xFF232B36)),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(symbol, style: TextStyle(color: selected ? const Color(0xFFFFFFFF) : const Color(0xFF9AA5B1), fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: selected ? const Color(0xFFFFFFFF) : const Color(0xFF9AA5B1), fontSize: 8),
            ),
          ],
        ),
      ),
    );
  }
}

class _MainDisplayCard extends StatelessWidget {
  const _MainDisplayCard({
    required this.title,
    required this.symbol,
    required this.measurement,
    required this.relativeValue,
    required this.isRelativeActive,
    required this.isHeld,
    required this.jackWarning,
  });

  final String title;
  final String symbol;
  final Measurement? measurement;
  final num? relativeValue;
  final bool isRelativeActive;
  final bool isHeld;
  final bool jackWarning;

  @override
  Widget build(BuildContext context) {
    final unavailable = measurement == null ||
        measurement!.state == MeasurementState.unavailable ||
        measurement!.state == MeasurementState.invalid;
    final displayNum = unavailable ? null : relativeValue;
    final unit = measurement?.unit ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF0A0E13), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1B222C))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title.toUpperCase(), style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                    const Text('AUTO RANGE', style: TextStyle(color: Color(0xFF5B6572), fontSize: 9, letterSpacing: 0.6)),
                  ],
                ),
              ),
              const Text('Auto', style: TextStyle(color: Color(0xFF9AA5B1), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                _formatValue(displayNum),
                style: const TextStyle(color: Color(0xFFE6E9EE), fontSize: 46, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(unit, style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 20, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
          if (jackWarning) ...[
            const SizedBox(height: 4),
            const Text('Red lead is in the wrong jack for this mode.', style: TextStyle(color: Color(0xFFEAB308), fontSize: 10)),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  isRelativeActive ? 'REL' : ' ',
                  style: const TextStyle(color: Color(0xFF9AA5B1), fontSize: 11),
                ),
              ),
              if (isHeld)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(4)),
                  child: const Text('HOLD', style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 11, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _Bargraph(value: displayNum),
        ],
      ),
    );
  }

  String _formatValue(num? value) {
    if (value == null) return '----';
    if (symbol == '•)))') return value != 0 ? 'BEEP' : 'OPEN';
    return value.truncateToDouble() == value ? value.toStringAsFixed(0) : value.toStringAsFixed(3);
  }
}

class _Bargraph extends StatelessWidget {
  const _Bargraph({required this.value});

  final num? value;

  static const double _range = 20;

  @override
  Widget build(BuildContext context) {
    final clamped = value == null ? 0.0 : (value!.clamp(-_range, _range)).toDouble();
    final fraction = (clamped + _range) / (2 * _range);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 22,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Row(
                    children: List.generate(41, (i) {
                      final isCenter = i == 20;
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                          height: isCenter ? 18 : 10,
                          color: const Color(0xFF232B36),
                        ),
                      );
                    }),
                  ),
                  Positioned(
                    left: (constraints.maxWidth * fraction - 1).clamp(0, constraints.maxWidth - 2),
                    child: Container(width: 2, height: 22, color: const Color(0xFF3B82F6)),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('-${_range.toStringAsFixed(0)}.00', style: const TextStyle(color: Color(0xFF5B6572), fontSize: 9)),
            const Text('0', style: TextStyle(color: Color(0xFF5B6572), fontSize: 9)),
            Text('+${_range.toStringAsFixed(0)}.00', style: const TextStyle(color: Color(0xFF5B6572), fontSize: 9)),
          ],
        ),
      ],
    );
  }
}

class _SecondaryButtonRow extends StatelessWidget {
  const _SecondaryButtonRow({required this.onTrend, required this.onMinMax, required this.onRecord});

  final VoidCallback onTrend;
  final VoidCallback onMinMax;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _GhostButton(label: 'TREND', onTap: onTrend)),
        const SizedBox(width: 8),
        Expanded(child: _GhostButton(label: 'MIN / MAX', onTap: onMinMax)),
        const SizedBox(width: 8),
        Expanded(child: _GhostButton(label: 'RECORD', onTap: onRecord)),
      ],
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFF11161D), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF232B36))),
        alignment: Alignment.center,
        child: Text(label, style: const TextStyle(color: Color(0xFF9AA5B1), fontSize: 10, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _InfoChipRow extends StatelessWidget {
  const _InfoChipRow();

  @override
  Widget build(BuildContext context) {
    // Cosmetic, static labels matching the reference design's
    // instrument-spec strip -- not computed from any real engine state
    // (this app has no real input-impedance/bandwidth/sample-rate
    // model), disclosed rather than presented as live telemetry.
    const chips = [
      ('INPUT IMP.', '10MΩ'),
      ('BANDWIDTH', 'Auto'),
      ('SAMPLE RATE', '10 S/s'),
      ('FILTER', 'Off'),
    ];
    return Row(
      children: [
        for (final chip in chips)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFF0F1216), borderRadius: BorderRadius.circular(6)),
              child: Column(
                children: [
                  Text(chip.$1, style: const TextStyle(color: Color(0xFF5B6572), fontSize: 8)),
                  const SizedBox(height: 2),
                  Text(chip.$2, style: const TextStyle(color: Color(0xFF9AA5B1), fontSize: 10, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.onNonHomeTap});

  final ValueChanged<String> onNonHomeTap;

  @override
  Widget build(BuildContext context) {
    const tabs = ['HOME', 'MEASURE', 'GRAPH', 'DATA', 'SETTINGS'];
    return Row(
      children: [
        for (final tab in tabs)
          Expanded(
            child: GestureDetector(
              onTap: tab == 'HOME' ? null : () => onNonHomeTap(_titleCase(tab)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  tab,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tab == 'HOME' ? const Color(0xFF3B82F6) : const Color(0xFF5B6572),
                    fontSize: 9,
                    fontWeight: tab == 'HOME' ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _titleCase(String s) => s[0] + s.substring(1).toLowerCase();
}

class _RotaryCluster extends StatelessWidget {
  const _RotaryCluster({
    required this.isHeld,
    required this.isRelativeActive,
    required this.onRel,
    required this.onHold,
    required this.onZero,
    required this.onMaxMin,
    required this.onSave,
    required this.onFunc,
  });

  final bool isHeld;
  final bool isRelativeActive;
  final VoidCallback onRel;
  final VoidCallback onHold;
  final VoidCallback onZero;
  final VoidCallback onMaxMin;
  final VoidCallback onSave;
  final VoidCallback onFunc;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            children: [
              _ClusterButton(label: 'REL', active: isRelativeActive, onTap: onRel),
              const SizedBox(height: 8),
              _ClusterButton(label: 'HOLD', active: isHeld, onTap: onHold),
              const SizedBox(height: 8),
              _ClusterButton(label: 'ZERO', active: false, onTap: onZero),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Container(
            height: 120,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF11161D),
              border: Border.all(color: const Color(0xFF3B82F6), width: 2),
            ),
            alignment: Alignment.center,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('RANGE', style: TextStyle(color: Color(0xFF5B6572), fontSize: 9, letterSpacing: 0.6)),
                SizedBox(height: 4),
                Text('AUTO', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              _ClusterButton(label: 'MAX/MIN', active: false, onTap: onMaxMin),
              const SizedBox(height: 8),
              _ClusterButton(label: 'SAVE', active: false, onTap: onSave),
              const SizedBox(height: 8),
              _ClusterButton(label: 'FUNC', active: false, onTap: onFunc),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClusterButton extends StatelessWidget {
  const _ClusterButton({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF3B82F6) : const Color(0xFF161C25),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? const Color(0xFF60A5FA) : const Color(0xFF232B36)),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: active ? const Color(0xFFFFFFFF) : const Color(0xFF9AA5B1), fontSize: 9, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _ProbeJackRow extends StatelessWidget {
  const _ProbeJackRow({required this.current, required this.onSelect});

  final DmmProbeJack current;
  final ValueChanged<DmmProbeJack> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _JackDot(label: '10A', caption: '10A MAX\nFUSED', jack: DmmProbeJack.tenAmp, current: current, onSelect: onSelect)),
        Expanded(child: _JackDot(label: 'mA µA', caption: '400mA MAX\nFUSED', jack: DmmProbeJack.milliamp, current: current, onSelect: onSelect)),
        Expanded(child: _JackDot(label: 'COM', caption: '', jack: DmmProbeJack.com, current: current, onSelect: null)),
        Expanded(child: _JackDot(label: 'VΩ', caption: '600V CAT III\n1000V CAT II', jack: DmmProbeJack.voltageOhm, current: current, onSelect: onSelect)),
      ],
    );
  }
}

class _JackDot extends StatelessWidget {
  const _JackDot({required this.label, required this.caption, required this.jack, required this.current, required this.onSelect});

  final String label;
  final String caption;
  final DmmProbeJack jack;
  final DmmProbeJack current;
  final ValueChanged<DmmProbeJack>? onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = jack == current;
    return GestureDetector(
      onTap: onSelect == null ? null : () => onSelect!(jack),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF11161D),
              border: Border.all(color: selected ? const Color(0xFFEF4444) : const Color(0xFF3B0D0D), width: selected ? 3 : 2),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0A0E13)),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Color(0xFF9AA5B1), fontSize: 10, fontWeight: FontWeight.w600)),
          if (caption.isNotEmpty)
            Text(
              caption,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF5B6572), fontSize: 7),
            ),
        ],
      ),
    );
  }
}

class _ToastBanner extends StatelessWidget {
  const _ToastBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(color: const Color(0xFF161C25), borderRadius: BorderRadius.circular(6)),
      alignment: Alignment.center,
      child: Text(text, style: const TextStyle(color: Color(0xFF9AA5B1), fontSize: 10)),
    );
  }
}

class _FooterTagline extends StatelessWidget {
  const _FooterTagline();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'ENGINEER  •  DESIGN  •  VALIDATE',
      textAlign: TextAlign.center,
      style: TextStyle(color: Color(0xFF3A4048), fontSize: 8, letterSpacing: 1),
    );
  }
}

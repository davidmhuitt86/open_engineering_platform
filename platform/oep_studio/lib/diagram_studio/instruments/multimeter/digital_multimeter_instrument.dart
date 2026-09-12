import 'package:flutter/material.dart';

import '../core/engineering_instrument.dart';
import 'digital_multimeter_instrument_panel.dart';

/// PRODUCT-READINESS-008 §19/§20 — completes the Digital Multimeter
/// [EngineeringInstrument] the instrument framework has declared since
/// WP-DS-005A but never had a concrete implementation for (confirmed:
/// `InstrumentRegistry` was never instantiated anywhere in the running
/// app before this phase). This class is a thin wrapper only — every
/// real behavior lives in [DigitalMultimeterInstrumentPanel] and
/// [MultimeterController]; this class never computes an engineering
/// measurement itself, matching [EngineeringInstrument]'s own contract.
class DigitalMultimeterInstrument extends EngineeringInstrument {
  const DigitalMultimeterInstrument();

  @override
  String get id => 'digitalMultimeter';

  @override
  String get title => 'Multimeter';

  @override
  IconData get icon => Icons.speed;

  @override
  String? get shortcutLabel => 'Ctrl+M';

  @override
  Widget buildPanel(BuildContext context) => const DigitalMultimeterInstrumentPanel();
}

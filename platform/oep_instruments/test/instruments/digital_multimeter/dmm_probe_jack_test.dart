import 'package:flutter_test/flutter_test.dart';
import 'package:oep_instruments_runtime/instruments/digital_multimeter/dmm_measurement_mode.dart';
import 'package:oep_instruments_runtime/instruments/digital_multimeter/dmm_probe_jack.dart';

void main() {
  group('isCorrectJackForMode', () {
    test('current mode requires mA or 10A jack, never VOhm', () {
      expect(isCorrectJackForMode(DmmProbeJack.milliamp, DmmMeasurementMode.current), isTrue);
      expect(isCorrectJackForMode(DmmProbeJack.tenAmp, DmmMeasurementMode.current), isTrue);
      expect(isCorrectJackForMode(DmmProbeJack.voltageOhm, DmmMeasurementMode.current), isFalse);
    });

    test('every non-current mode requires the VOhm jack', () {
      for (final mode in DmmMeasurementMode.values) {
        if (mode == DmmMeasurementMode.current) continue;
        expect(isCorrectJackForMode(DmmProbeJack.voltageOhm, mode), isTrue, reason: '$mode should require VOhm');
        expect(isCorrectJackForMode(DmmProbeJack.milliamp, mode), isFalse, reason: '$mode should reject mA');
      }
    });
  });
}

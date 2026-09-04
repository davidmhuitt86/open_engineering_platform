/// A tiny dense Gaussian-elimination solver with partial pivoting. This
/// is the general linear-system foundation the Modified Nodal Analysis
/// stamps in `analysis_engine.dart` are solved with — not a hardcoded
/// "voltage divided by resistance" shortcut (AP-EK-020 §14).
library;

class SingularSystemException implements Exception {
  final String message;
  const SingularSystemException(this.message);

  @override
  String toString() => 'SingularSystemException: $message';
}

/// Solves `a * x = b` for `x`. `a` is square (`n x n`), `b` has length
/// `n`. Throws [SingularSystemException] if no pivot exceeds [epsilon].
List<double> solveLinearSystem(
  List<List<double>> a,
  List<double> b, {
  double epsilon = 1e-12,
}) {
  final n = b.length;
  final m = List.generate(n, (i) => [...a[i]]);
  final rhs = [...b];

  for (var col = 0; col < n; col++) {
    var pivotRow = col;
    var pivotMagnitude = m[col][col].abs();
    for (var row = col + 1; row < n; row++) {
      final magnitude = m[row][col].abs();
      if (magnitude > pivotMagnitude) {
        pivotRow = row;
        pivotMagnitude = magnitude;
      }
    }
    if (pivotMagnitude < epsilon) {
      throw SingularSystemException(
        'No usable pivot in column $col (largest magnitude $pivotMagnitude).',
      );
    }
    if (pivotRow != col) {
      final tmpRow = m[col];
      m[col] = m[pivotRow];
      m[pivotRow] = tmpRow;
      final tmpB = rhs[col];
      rhs[col] = rhs[pivotRow];
      rhs[pivotRow] = tmpB;
    }

    for (var row = col + 1; row < n; row++) {
      final factor = m[row][col] / m[col][col];
      if (factor == 0) continue;
      for (var k = col; k < n; k++) {
        m[row][k] -= factor * m[col][k];
      }
      rhs[row] -= factor * rhs[col];
    }
  }

  final x = List<double>.filled(n, 0);
  for (var row = n - 1; row >= 0; row--) {
    var sum = rhs[row];
    for (var col = row + 1; col < n; col++) {
      sum -= m[row][col] * x[col];
    }
    x[row] = sum / m[row][row];
  }
  return x;
}

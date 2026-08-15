import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/knowledge/services/tesseract_tsv_parser.dart';

void main() {
  group('TesseractTsvParser.parse', () {
    // Captured verbatim from a real `tesseract 5.4.0.20240606` run
    // (`tesseract sample.png stdout tsv`) against a 400x120 PNG reading
    // "Torque Spec 35 Nm" — see `docs/OCR_PIPELINE.md` § OCR
    // Architecture for the exact command and column layout.
    const realTsv = '''
level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext
1\t1\t0\t0\t0\t0\t0\t0\t400\t120\t-1\t
2\t1\t1\t0\t0\t0\t15\t46\t287\t29\t-1\t
3\t1\t1\t1\t0\t0\t15\t46\t287\t29\t-1\t
4\t1\t1\t1\t1\t0\t15\t46\t287\t29\t-1\t
5\t1\t1\t1\t1\t1\t15\t46\t102\t29\t96.353775\tTorque
5\t1\t1\t1\t1\t2\t128\t46\t72\t29\t96.296837\tSpec
5\t1\t1\t1\t1\t3\t210\t46\t34\t23\t95.434517\t35
5\t1\t1\t1\t1\t4\t256\t46\t46\t23\t95.434517\tNm
''';

    test('extracts the page image dimensions from the level-1 row', () {
      final output = TesseractTsvParser.parse(realTsv);
      expect(output.imageWidth, 400);
      expect(output.imageHeight, 120);
    });

    test('extracts exactly the four words, skipping block/paragraph/line rows', () {
      final output = TesseractTsvParser.parse(realTsv);
      expect(output.words.map((w) => w.text).toList(), ['Torque', 'Spec', '35', 'Nm']);
    });

    test('normalizes confidence from 0-100 to 0.0-1.0', () {
      final output = TesseractTsvParser.parse(realTsv);
      expect(output.words[0].confidence, closeTo(0.96353775, 1e-9));
    });

    test('converts pixel bounding boxes into page-fraction coordinates', () {
      final output = TesseractTsvParser.parse(realTsv);
      final torque = output.words[0];
      expect(torque.boundingBox.x, closeTo(15 / 400, 1e-9));
      expect(torque.boundingBox.y, closeTo(46 / 120, 1e-9));
      expect(torque.boundingBox.width, closeTo(102 / 400, 1e-9));
      expect(torque.boundingBox.height, closeTo(29 / 120, 1e-9));
    });

    test('assigns sequential reading order matching TSV emission order', () {
      final output = TesseractTsvParser.parse(realTsv);
      expect(output.words.map((w) => w.readingOrder).toList(), [0, 1, 2, 3]);
    });

    test('all four words on one printed line share the same lineIndex', () {
      final output = TesseractTsvParser.parse(realTsv);
      expect(output.words.map((w) => w.lineIndex).toSet(), {0});
    });

    test('two distinct lines get two distinct lineIndex values, in encounter order', () {
      const twoLineTsv = '''
level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext
1\t1\t0\t0\t0\t0\t0\t0\t200\t100\t-1\t
5\t1\t1\t1\t1\t1\t10\t10\t50\t20\t90\tFirst
5\t1\t1\t1\t2\t1\t10\t40\t50\t20\t90\tSecond
''';
      final output = TesseractTsvParser.parse(twoLineTsv);
      expect(output.words[0].lineIndex, 0);
      expect(output.words[1].lineIndex, 1);
    });

    test('a blank page (page row only, no word rows) produces an empty word list', () {
      const blankTsv = '''
level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext
1\t1\t0\t0\t0\t0\t0\t0\t400\t120\t-1\t
''';
      final output = TesseractTsvParser.parse(blankTsv);
      expect(output.words, isEmpty);
      expect(output.imageWidth, 400);
    });

    test('throws FormatException when no page-level row is present', () {
      const noPageRow = 'level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n';
      expect(() => TesseractTsvParser.parse(noPageRow), throwsFormatException);
    });

    test('strips trailing \\r from every word\'s text on Windows-style CRLF output', () {
      // A real `tesseract ... stdout tsv` run on Windows terminates
      // every row with \r\n, not just \n — caught during Work Package
      // 013's manual verification against a real generated PNG, where
      // every recognized word carried a hidden trailing '\r' that broke
      // Find/Find Next (a query never matched, since "oil\r filter"
      // is not a clean substring of "oil filter").
      const crlfTsv =
          'level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\r\n'
          '1\t1\t0\t0\t0\t0\t0\t0\t400\t120\t-1\t\r\n'
          '5\t1\t1\t1\t1\t1\t15\t46\t102\t29\t96.35\tTorque\r\n'
          '5\t1\t1\t1\t1\t2\t128\t46\t72\t29\t96.29\tSpec\r\n';
      final output = TesseractTsvParser.parse(crlfTsv);
      expect(output.words.map((w) => w.text).toList(), ['Torque', 'Spec']);
      for (final word in output.words) {
        expect(word.text.contains('\r'), isFalse);
      }
    });
  });
}

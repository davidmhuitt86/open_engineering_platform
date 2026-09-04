import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A minimal, read-only ZIP archive reader — just enough of the format
/// (PKWARE APPNOTE central-directory-based reading, STORED and
/// DEFLATE-compressed entries) to open a `.oerp` package. Hand-rolled
/// rather than adding `package:archive` as a new production dependency,
/// following this codebase's existing convention for small,
/// well-specified formats (see `sha256Hex` in `knowledge_package.dart`)
/// — the ZIP *container* is a small, fully-specified binary layout;
/// the only non-trivial piece, DEFLATE decompression, is not
/// reimplemented here — it is delegated to `dart:io`'s built-in
/// `ZLibDecoder(raw: true)`, which already ships with the Dart SDK.
///
/// Read-only. No write/create support — this reader exists solely to
/// open packages the Reference Compiler already produced.
class MinimalZipReader {
  final Uint8List _bytes;
  final Map<String, _ZipEntry> _entriesByName;

  MinimalZipReader._(this._bytes, this._entriesByName);

  factory MinimalZipReader(Uint8List bytes) {
    final eocdOffset = _findEndOfCentralDirectory(bytes);
    final view = ByteData.sublistView(bytes);

    final entryCount = view.getUint16(eocdOffset + 10, Endian.little);
    final centralDirSize = view.getUint32(eocdOffset + 12, Endian.little);
    final centralDirOffset = view.getUint32(eocdOffset + 16, Endian.little);
    if (centralDirOffset + centralDirSize > bytes.length) {
      throw const FormatException(
        'ZIP central directory extends past end of file.',
      );
    }

    final entries = <String, _ZipEntry>{};
    var cursor = centralDirOffset;
    for (var i = 0; i < entryCount; i++) {
      const centralHeaderSignature = 0x02014b50;
      final signature = view.getUint32(cursor, Endian.little);
      if (signature != centralHeaderSignature) {
        throw FormatException(
          'Malformed ZIP: expected central directory header at offset $cursor.',
        );
      }
      final compressionMethod = view.getUint16(cursor + 10, Endian.little);
      final compressedSize = view.getUint32(cursor + 20, Endian.little);
      final uncompressedSize = view.getUint32(cursor + 24, Endian.little);
      final filenameLength = view.getUint16(cursor + 28, Endian.little);
      final extraLength = view.getUint16(cursor + 30, Endian.little);
      final commentLength = view.getUint16(cursor + 32, Endian.little);
      final localHeaderOffset = view.getUint32(cursor + 42, Endian.little);

      final filenameStart = cursor + 46;
      final filename = utf8.decode(
        bytes.sublist(filenameStart, filenameStart + filenameLength),
      );

      entries[filename] = _ZipEntry(
        compressionMethod: compressionMethod,
        compressedSize: compressedSize,
        uncompressedSize: uncompressedSize,
        localHeaderOffset: localHeaderOffset,
      );

      cursor = filenameStart + filenameLength + extraLength + commentLength;
    }

    return MinimalZipReader._(bytes, entries);
  }

  bool containsEntry(String name) => _entriesByName.containsKey(name);

  List<String> get entryNames => _entriesByName.keys.toList(growable: false);

  /// Reads and decompresses one entry's content by its archive path.
  /// Throws [ArgumentError] if [name] is not present, and
  /// [FormatException] for an unsupported compression method.
  Uint8List readEntry(String name) {
    final entry = _entriesByName[name];
    if (entry == null) {
      throw ArgumentError(
        'No entry named "$name" in this archive. Present: ${entryNames.join(", ")}',
      );
    }
    final view = ByteData.sublistView(_bytes);
    const localHeaderSignature = 0x04034b50;
    final signature = view.getUint32(entry.localHeaderOffset, Endian.little);
    if (signature != localHeaderSignature) {
      throw FormatException(
        'Malformed ZIP: expected local file header for "$name".',
      );
    }
    final filenameLength = view.getUint16(
      entry.localHeaderOffset + 26,
      Endian.little,
    );
    final extraLength = view.getUint16(
      entry.localHeaderOffset + 28,
      Endian.little,
    );
    final dataStart =
        entry.localHeaderOffset + 30 + filenameLength + extraLength;
    final compressedBytes = _bytes.sublist(
      dataStart,
      dataStart + entry.compressedSize,
    );

    switch (entry.compressionMethod) {
      case 0: // Stored (no compression).
        return compressedBytes;
      case 8: // Deflated.
        final decoder = ZLibDecoder(raw: true);
        final decoded = decoder.convert(compressedBytes);
        return Uint8List.fromList(decoded);
      default:
        throw FormatException(
          'Unsupported ZIP compression method ${entry.compressionMethod} for entry "$name" '
          '(only STORED and DEFLATE are supported).',
        );
    }
  }

  String readEntryAsString(String name) => utf8.decode(readEntry(name));

  static int _findEndOfCentralDirectory(Uint8List bytes) {
    const eocdSignature = 0x06054b50;
    const minEocdSize = 22;
    // The EOCD record is a fixed 22 bytes plus an optional trailing
    // comment (max 65535 bytes) — scan backward from the end for the
    // signature rather than assuming no comment.
    final searchFloor = bytes.length - minEocdSize - 0xFFFF < 0
        ? 0
        : bytes.length - minEocdSize - 0xFFFF;
    for (
      var offset = bytes.length - minEocdSize;
      offset >= searchFloor;
      offset--
    ) {
      if (bytes[offset] == 0x50 &&
          bytes[offset + 1] == 0x4b &&
          bytes[offset + 2] == 0x05 &&
          bytes[offset + 3] == 0x06) {
        final candidateSignature = ByteData.sublistView(
          bytes,
        ).getUint32(offset, Endian.little);
        if (candidateSignature == eocdSignature) return offset;
      }
    }
    throw const FormatException(
      'Not a valid ZIP archive: no End Of Central Directory record found.',
    );
  }
}

class _ZipEntry {
  final int compressionMethod;
  final int compressedSize;
  final int uncompressedSize;
  final int localHeaderOffset;

  const _ZipEntry({
    required this.compressionMethod,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.localHeaderOffset,
  });
}

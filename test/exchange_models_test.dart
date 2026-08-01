import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/exchange/models/exchange_package.dart';
import 'package:oep_studio/exchange/models/installation.dart';
import 'package:oep_studio/exchange/models/library_entry.dart';
import 'package:oep_studio/exchange/models/publisher.dart';
import 'package:oep_studio/exchange/models/search_result_item.dart';

/// Wire-shape mirroring for every Exchange model (WP-EXC-010) --
/// `fromJson` must read exactly the `camelCase` field names
/// `packages/api-contracts` actually serializes, since a mismatch here
/// would silently produce blank/zeroed fields rather than a compile
/// error.
void main() {
  group('Publisher.fromJson', () {
    test('reads every PublisherDto field', () {
      final publisher = Publisher.fromJson(const {
        'id': 'pub-1',
        'namespace': 'com.example',
        'publisherType': 'company',
        'displayName': 'Example Co',
        'legalName': 'Example Company LLC',
        'description': 'An example publisher.',
        'website': 'https://example.test',
        'contactEmail': 'hello@example.test',
        'status': 'active',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-02T00:00:00.000Z',
      });
      expect(publisher.id, 'pub-1');
      expect(publisher.namespace, 'com.example');
      expect(publisher.publisherType, 'company');
      expect(publisher.displayName, 'Example Co');
      expect(publisher.status, 'active');
    });
  });

  group('ExchangePackage.fromJson', () {
    test('reads every PackageDto field, including nullable ones', () {
      final package = ExchangePackage.fromJson(const {
        'id': 'pkg-1',
        'packageId': 'com.example.widget',
        'publisherId': 'pub-1',
        'displayName': 'Widget',
        'description': 'A widget package.',
        'categoryId': null,
        'currentVersion': '1.2.3',
        'status': 'published',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-02T00:00:00.000Z',
      });
      expect(package.id, 'pkg-1');
      expect(package.packageId, 'com.example.widget');
      expect(package.categoryId, isNull);
      expect(package.currentVersion, '1.2.3');
    });
  });

  group('ExchangeSearchResponse.fromJson', () {
    test('parses pagination metadata and nested items', () {
      final response = ExchangeSearchResponse.fromJson(const {
        'items': [
          {
            'id': 'pkg-1',
            'packageId': 'com.example.widget',
            'publisherId': 'pub-1',
            'publisherName': 'Example Co',
            'displayName': 'Widget',
            'description': 'A widget package.',
            'categoryId': null,
            'categoryName': null,
            'currentVersion': '1.2.3',
            'status': 'published',
            'createdAt': '2026-01-01T00:00:00.000Z',
            'updatedAt': '2026-01-02T00:00:00.000Z',
          },
        ],
        'totalCount': 1,
        'totalPages': 1,
        'currentPage': 1,
        'pageSize': 20,
      });
      expect(response.items, hasLength(1));
      expect(response.items.single.publisherName, 'Example Co');
      expect(response.totalCount, 1);
    });

    test('ExchangeSearchResponse.empty has no items and a sensible default page', () {
      expect(ExchangeSearchResponse.empty.items, isEmpty);
      expect(ExchangeSearchResponse.empty.currentPage, 1);
    });
  });

  group('Installation.fromJson', () {
    test('status helpers reflect the raw status string', () {
      final completed = Installation.fromJson(const {
        'id': 'install-1',
        'packageId': 'pkg-1',
        'version': '1.0.0',
        'status': 'completed',
        'repositoryPackageId': 'repo-pkg-1',
        'errorMessage': null,
        'requestedAt': '2026-01-01T00:00:00.000Z',
        'completedAt': '2026-01-01T00:01:00.000Z',
      });
      expect(completed.isCompleted, isTrue);
      expect(completed.isFailed, isFalse);

      final failed = Installation.fromJson(const {
        'id': 'install-2',
        'packageId': 'pkg-1',
        'version': '1.0.0',
        'status': 'failed',
        'repositoryPackageId': null,
        'errorMessage': 'The Repository rejected the package.',
        'requestedAt': '2026-01-01T00:00:00.000Z',
        'completedAt': null,
      });
      expect(failed.isFailed, isTrue);
      expect(failed.errorMessage, 'The Repository rejected the package.');
    });
  });

  group('LibraryEntry/DownloadEntry JSON round-trip', () {
    test('LibraryEntry round-trips and copyWith updates only status', () {
      const entry = LibraryEntry(
        packageId: 'pkg-1',
        displayName: 'Widget',
        version: '1.0.0',
        installationId: 'install-1',
        status: 'pending',
        requestedAt: '2026-01-01T00:00:00.000Z',
      );
      final restored = LibraryEntry.fromJson(entry.toJson());
      expect(restored.packageId, entry.packageId);
      expect(restored.status, 'pending');

      final updated = entry.copyWith(status: 'completed');
      expect(updated.status, 'completed');
      expect(updated.packageId, entry.packageId);
    });

    test('DownloadEntry round-trips through JSON', () {
      const entry = DownloadEntry(
        packageId: 'pkg-1',
        displayName: 'Widget',
        version: '1.0.0',
        downloadedAt: '2026-01-01T00:00:00.000Z',
      );
      final restored = DownloadEntry.fromJson(entry.toJson());
      expect(restored.packageId, 'pkg-1');
      expect(restored.version, '1.0.0');
    });
  });
}

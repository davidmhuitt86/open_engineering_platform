import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oep_studio/knowledge/models/knowledge_session.dart';
import 'package:oep_studio/knowledge/models/knowledge_session_record.dart';
import 'package:oep_studio/knowledge/models/knowledge_validation_exception.dart';
import 'package:oep_studio/knowledge/services/knowledge_session_storage.dart';

KnowledgeSessionRecord _record(String id, String name) => KnowledgeSessionRecord(
      session: KnowledgeSession(
        id: id,
        name: name,
        repositoryName: 'repo',
        author: 'tester',
        createdTime: DateTime(2026, 1, 1),
        lastModified: DateTime(2026, 1, 1),
      ),
    );

String _nameIn(String json) => (jsonDecode(json) as Map<String, dynamic>)['session']['name'] as String;

void main() {
  final createdIds = <String>[];

  String newId(String tag) {
    final id = 'followup006-$tag-${DateTime.now().microsecondsSinceEpoch}';
    createdIds.add(id);
    return id;
  }

  tearDown(() async {
    KnowledgeSessionStorage.debugSetWriter(null);
    for (final id in createdIds) {
      for (var attempt = 0; attempt < 10; attempt++) {
        try {
          final dir = KnowledgeSessionStorage.sessionDirectory(id);
          if (dir.existsSync()) dir.deleteSync(recursive: true);
          break;
        } on FileSystemException {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    }
    createdIds.clear();
  });

  test('A: sequential awaited saves leave a valid file holding the last state', () async {
    final id = newId('a');
    await KnowledgeSessionStorage.save(_record(id, 'A'));
    await KnowledgeSessionStorage.save(_record(id, 'B'));
    await KnowledgeSessionStorage.save(_record(id, 'C'));
    final loaded = await KnowledgeSessionStorage.load(id);
    expect(loaded.session.name, 'C');
  });

  test('B/C: overlapping saves never overlap, run in request order, and all complete', () async {
    final id = newId('b');
    final events = <String>[];
    var active = 0;
    var maxActive = 0;
    final gates = <String, Completer<void>>{
      'A': Completer<void>(),
      'B': Completer<void>(),
      'C': Completer<void>(),
    };
    KnowledgeSessionStorage.debugSetWriter((sessionId, json) async {
      final name = _nameIn(json);
      events.add('$name start');
      active++;
      if (active > maxActive) maxActive = active;
      await gates[name]!.future;
      active--;
      events.add('$name end');
    });

    final futures = [
      KnowledgeSessionStorage.save(_record(id, 'A')),
      KnowledgeSessionStorage.save(_record(id, 'B')),
      KnowledgeSessionStorage.save(_record(id, 'C')),
    ];
    await pumpEventQueue();
    expect(events, ['A start'], reason: 'B and C must wait for A');

    // Release out of order: later gates first must not let them run early.
    gates['C']!.complete();
    gates['B']!.complete();
    await pumpEventQueue();
    expect(events, ['A start']);
    gates['A']!.complete();
    await Future.wait(futures);

    expect(events, ['A start', 'A end', 'B start', 'B end', 'C start', 'C end']);
    expect(maxActive, 1);
  });

  test('D: a failed save rejects its own future but does not poison the queue', () async {
    final id = newId('d');
    final written = <String>[];
    KnowledgeSessionStorage.debugSetWriter((sessionId, json) async {
      final name = _nameIn(json);
      if (name == 'A') throw const FileSystemException('disk full');
      written.add(name);
    });

    final a = KnowledgeSessionStorage.save(_record(id, 'A'));
    final b = KnowledgeSessionStorage.save(_record(id, 'B'));
    final c = KnowledgeSessionStorage.save(_record(id, 'C'));

    await expectLater(a, throwsA(isA<KnowledgeValidationException>()));
    await b;
    await c;
    expect(written, ['B', 'C']);
  });

  test('E: different sessions use independent queues', () async {
    final idX = newId('ex');
    final idY = newId('ey');
    final gate = Completer<void>();
    final started = <String>[];
    KnowledgeSessionStorage.debugSetWriter((sessionId, json) async {
      started.add(sessionId);
      if (sessionId == idX) await gate.future;
    });

    final x = KnowledgeSessionStorage.save(_record(idX, 'X'));
    final y = KnowledgeSessionStorage.save(_record(idY, 'Y'));
    await y; // completes although X's write is still blocked
    expect(started, [idX, idY]);
    gate.complete();
    await x;
  });

  test('snapshot-at-request: each write carries the state passed to its own save', () async {
    final id = newId('snap');
    final seen = <String>[];
    final gate = Completer<void>();
    KnowledgeSessionStorage.debugSetWriter((sessionId, json) async {
      seen.add(_nameIn(json));
      if (seen.length == 1) await gate.future;
    });
    final first = KnowledgeSessionStorage.save(_record(id, 'first'));
    final second = KnowledgeSessionStorage.save(_record(id, 'second'));
    gate.complete();
    await Future.wait([first, second]);
    expect(seen, ['first', 'second']);
  });

  test('F: rapid fire-and-forget saves with real writes leave a loadable file with the last state', () async {
    final id = newId('f');
    final futures = <Future<void>>[
      for (var i = 0; i < 40; i++) KnowledgeSessionStorage.save(_record(id, 'edit-$i')),
    ];
    await Future.wait(futures);
    final loaded = await KnowledgeSessionStorage.load(id);
    expect(loaded.session.name, 'edit-39');
  });

  test('delete queued behind pending saves is not resurrected by them', () async {
    final id = newId('del');
    await KnowledgeSessionStorage.save(_record(id, 'seed'));
    final saves = [for (var i = 0; i < 5; i++) KnowledgeSessionStorage.save(_record(id, 'n$i'))];
    final deletion = KnowledgeSessionStorage.delete(id);
    await Future.wait([...saves, deletion]);
    expect(KnowledgeSessionStorage.sessionDirectory(id).existsSync(), isFalse);
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/acquisition_job.dart';
import '../models/official_source.dart';
import '../models/vault_entry_record.dart';

/// Whatever the engineer last selected in an Engineering Acquisition
/// panel — drives the Property Inspector's Acquisition modes ("If
/// Official Source selected → Source properties; if Acquisition Job
/// selected → Job properties; if Artifact selected → Artifact
/// properties").
///
/// Deliberately a **separate, small provider** rather than new fields on
/// `FoundationServiceState`: Foundation's own selection state is about
/// Engineering Objects/Relationships/Knowledge Candidates that come from
/// the Foundation runtime, while these three come from EAM's REST API
/// and have no Foundation representation at all. Mutually exclusive by
/// construction (setting one clears the others), matching how
/// `FoundationRuntimeNotifier`'s own `selectObject`/`selectRelationship`
/// behave.
class AcquisitionSelection {
  const AcquisitionSelection({this.source, this.job, this.artifact});

  final OfficialSource? source;
  final AcquisitionJob? job;
  final VaultEntryRecord? artifact;

  bool get isEmpty => source == null && job == null && artifact == null;
}

class AcquisitionSelectionNotifier extends Notifier<AcquisitionSelection> {
  @override
  AcquisitionSelection build() => const AcquisitionSelection();

  void selectSource(OfficialSource source) => state = AcquisitionSelection(source: source);
  void selectJob(AcquisitionJob job) => state = AcquisitionSelection(job: job);
  void selectArtifact(VaultEntryRecord artifact) => state = AcquisitionSelection(artifact: artifact);
  void clear() => state = const AcquisitionSelection();
}

final acquisitionSelectionProvider =
    NotifierProvider<AcquisitionSelectionNotifier, AcquisitionSelection>(AcquisitionSelectionNotifier.new);

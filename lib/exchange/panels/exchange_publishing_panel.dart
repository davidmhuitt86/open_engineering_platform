import 'package:flutter/material.dart';

import '../../core/theme/studio_colors.dart';

/// Publishing (Phase 7). The approved render (`11_Engineering_Exchange.png`)
/// shows a Publisher Dashboard with Total Revenue/Payouts/Analytics --
/// none of that exists anywhere: `foundation_bridge.dart` has no
/// `createPackage`/`buildPackage`/`signPackage`/`publishPackage` entry
/// point, `exchange_api_client.dart` has no publish/submit endpoint, and
/// there is no revenue, payout, or analytics concept anywhere in either
/// the Foundation Bridge or the Exchange REST client (confirmed by
/// inspection before this file was written). This panel exists so
/// "Publishing" is a real, reachable, honestly-labeled section of the
/// Exchange workspace rather than a missing capability the engineer has
/// no way to even ask about -- not a partial or simulated publishing
/// flow. See `docs/ui_refactor/PHASE_7_NOTES.md`.
class ExchangePublishingPanel extends StatelessWidget {
  const ExchangePublishingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.upload_outlined, size: 48, color: StudioColors.textDisabled),
            const SizedBox(height: 16),
            const Text(
              'Publishing Not Yet Available',
              style: TextStyle(color: StudioColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const SizedBox(
              width: 420,
              child: Text(
                'Building, signing, and publishing packages to the Engineering Exchange requires backend '
                'capability that does not exist yet -- there is no package-authoring, signing, or publish '
                'API in either the Foundation Bridge or the Exchange service today. This section will '
                'connect to that capability once it exists.',
                textAlign: TextAlign.center,
                style: TextStyle(color: StudioColors.textSecondary, fontSize: 13, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

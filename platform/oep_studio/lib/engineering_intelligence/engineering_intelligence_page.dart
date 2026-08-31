import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/routing/studio_destination.dart';
import '../core/services/foundation_runtime_service.dart';
import '../core/theme/studio_colors.dart';
import '../shared/navigation/workspace_aware_navigation.dart';
import 'pages/analysis_dashboard_page.dart';
import 'pages/engineering_explorer_page.dart';
import 'pages/knowledge_graph_explorer_page.dart';
import 'pages/knowledge_session_manager_page.dart';
import 'pages/query_console_page.dart';
import 'pages/reasoning_dashboard_page.dart';
import 'pages/recommendation_panel_page.dart';
import 'pages/validation_dashboard_page.dart';

/// The Engineering Intelligence Studio (WP-EKE-008 "Studio Integration"):
/// the first Studio in the WP-EKE series to carry real UI rather than
/// FFI bindings only (WP-EKE-001 through WP-EKE-007 were bindings-only
/// by explicit design). Every page below reads the Engineering
/// Knowledge Engine exclusively through [FoundationBridge] — obtained
/// from `FoundationRuntimeNotifier.bridge`, the one place in Studio
/// that owns a live bridge handle — and never touches `dart:ffi` or a
/// native type directly.
///
/// Structure: one Studio destination on the Navigation Rail
/// (`StudioDestination.engineeringIntelligence`), containing all eight
/// required pages as an in-page `TabBar`, rather than eight separate
/// top-level Navigation Rail entries. This mirrors how `SettingsWorkspacePage`
/// already groups many sub-pages behind one destination, and keeps the
/// Navigation Rail from growing by eight items for what is really one
/// cohesive capability area (a judgment call — the alternative of eight
/// flat destinations was also reasonable but felt noisier for a first
/// pass).
class EngineeringIntelligencePage extends ConsumerStatefulWidget {
  const EngineeringIntelligencePage({super.key});

  @override
  ConsumerState<EngineeringIntelligencePage> createState() => _EngineeringIntelligencePageState();
}

class _EngineeringIntelligencePageState extends ConsumerState<EngineeringIntelligencePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    Tab(icon: Icon(Icons.explore_outlined, size: 18), text: 'Explorer'),
    Tab(icon: Icon(Icons.account_tree_outlined, size: 18), text: 'Knowledge Graph'),
    Tab(icon: Icon(Icons.terminal_outlined, size: 18), text: 'Query Console'),
    Tab(icon: Icon(Icons.fact_check_outlined, size: 18), text: 'Validation'),
    Tab(icon: Icon(Icons.insights_outlined, size: 18), text: 'Analysis'),
    Tab(icon: Icon(Icons.psychology_outlined, size: 18), text: 'Reasoning'),
    Tab(icon: Icon(Icons.lightbulb_outline, size: 18), text: 'Recommendations'),
    Tab(icon: Icon(Icons.folder_shared_outlined, size: 18), text: 'Sessions'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foundation = ref.watch(foundationRuntimeServiceProvider);

    if (!foundation.isRepositoryOpen) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.psychology_outlined, size: 48, color: StudioColors.textDisabled),
            const SizedBox(height: 16),
            const Text(
              'No Repository Open',
              style: TextStyle(color: StudioColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Open a repository to explore the Engineering Knowledge Engine.',
              style: TextStyle(color: StudioColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => openOrActivateDestination(context, ref, StudioDestination.repository),
              child: const Text('Go to Repository Explorer'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          color: StudioColors.surface,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: StudioColors.selection,
            unselectedLabelColor: StudioColors.textSecondary,
            indicatorColor: StudioColors.selection,
            tabs: _tabs,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              EngineeringExplorerPage(),
              KnowledgeGraphExplorerPage(),
              QueryConsolePage(),
              ValidationDashboardPage(),
              AnalysisDashboardPage(),
              ReasoningDashboardPage(),
              RecommendationPanelPage(),
              KnowledgeSessionManagerPage(),
            ],
          ),
        ),
      ],
    );
  }
}

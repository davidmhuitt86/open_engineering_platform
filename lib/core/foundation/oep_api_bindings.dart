import 'dart:ffi';
import 'dart:io';

import 'oep_api_native_types.dart';

/// Loads `oep_foundation_bridge.dll` and exposes typed Dart wrappers for
/// every function declared in `oep_api.h`. This class performs no
/// marshaling beyond what `dart:ffi` does automatically — struct decoding,
/// error translation, and lifecycle management belong to
/// `foundation_bridge.dart`.
class OepApiBindings {
  factory OepApiBindings.load() {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'The Foundation Bridge is only available on Windows in this build. '
        'oep_foundation_bridge.dll is produced by windows/CMakeLists.txt.',
      );
    }
    final library = DynamicLibrary.open('oep_foundation_bridge.dll');
    return OepApiBindings._(library);
  }

  OepApiBindings._(this._library)
    : foundationVersion = _library.lookupFunction<OepFoundationVersionNative, OepFoundationVersionDart>(
        'oep_foundation_version',
      ),
      apiVersion = _library.lookupFunction<OepApiVersionNative, OepApiVersionDart>('oep_api_version'),
      abiVersion = _library.lookupFunction<OepAbiVersionNative, OepAbiVersionDart>('oep_abi_version'),
      runtimeStateToString = _library
          .lookupFunction<OepRuntimeStateToStringNative, OepRuntimeStateToStringDart>(
            'oep_runtime_state_to_string',
          ),
      errorCodeToString = _library.lookupFunction<OepErrorCodeToStringNative, OepErrorCodeToStringDart>(
        'oep_error_code_to_string',
      ),
      errorCategoryToString = _library
          .lookupFunction<OepErrorCategoryToStringNative, OepErrorCategoryToStringDart>(
            'oep_error_category_to_string',
          ),
      runtimeCreate = _library.lookupFunction<OepRuntimeCreateNative, OepRuntimeCreateDart>('oep_runtime_create'),
      runtimeDestroy = _library.lookupFunction<OepRuntimeDestroyNative, OepRuntimeDestroyDart>(
        'oep_runtime_destroy',
      ),
      runtimeInitialize = _library.lookupFunction<OepRuntimeInitializeNative, OepRuntimeInitializeDart>(
        'oep_runtime_initialize',
      ),
      runtimeOpenRepository = _library
          .lookupFunction<OepRuntimeOpenRepositoryNative, OepRuntimeOpenRepositoryDart>(
            'oep_runtime_open_repository',
          ),
      runtimeCloseRepository = _library
          .lookupFunction<OepRuntimeCloseRepositoryNative, OepRuntimeCloseRepositoryDart>(
            'oep_runtime_close_repository',
          ),
      runtimeShutdown = _library.lookupFunction<OepRuntimeShutdownNative, OepRuntimeShutdownDart>(
        'oep_runtime_shutdown',
      ),
      runtimeGetState = _library.lookupFunction<OepRuntimeGetStateNative, OepRuntimeGetStateDart>(
        'oep_runtime_get_state',
      ),
      runtimeGetRepositoryStatus = _library
          .lookupFunction<OepRuntimeGetRepositoryStatusNative, OepRuntimeGetRepositoryStatusDart>(
            'oep_runtime_get_repository_status',
          ),
      objectTypeToString = _library.lookupFunction<OepObjectTypeToStringNative, OepObjectTypeToStringDart>(
        'oep_object_type_to_string',
      ),
      objectStoreGetCount = _library.lookupFunction<OepObjectStoreGetCountNative, OepObjectStoreGetCountDart>(
        'oep_object_store_get_count',
      ),
      objectStoreGetById = _library.lookupFunction<OepObjectStoreGetByIdNative, OepObjectStoreGetByIdDart>(
        'oep_object_store_get_by_id',
      ),
      objectStoreList = _library.lookupFunction<OepObjectStoreListNative, OepObjectStoreListDart>(
        'oep_object_store_list',
      ),
      objectListRelease = _library.lookupFunction<OepObjectListReleaseNative, OepObjectListReleaseDart>(
        'oep_object_list_release',
      ),
      runtimeGetRepositoryStatistics = _library
          .lookupFunction<OepRuntimeGetRepositoryStatisticsNative, OepRuntimeGetRepositoryStatisticsDart>(
            'oep_runtime_get_repository_statistics',
          ),
      relationshipTypeToString = _library
          .lookupFunction<OepRelationshipTypeToStringNative, OepRelationshipTypeToStringDart>(
            'oep_relationship_type_to_string',
          ),
      relationshipStoreGetCount = _library
          .lookupFunction<OepRelationshipStoreGetCountNative, OepRelationshipStoreGetCountDart>(
            'oep_relationship_store_get_count',
          ),
      relationshipStoreGetById = _library
          .lookupFunction<OepRelationshipStoreGetByIdNative, OepRelationshipStoreGetByIdDart>(
            'oep_relationship_store_get_by_id',
          ),
      relationshipStoreList = _library
          .lookupFunction<OepRelationshipStoreListNative, OepRelationshipStoreListDart>(
            'oep_relationship_store_list',
          ),
      relationshipListRelease = _library
          .lookupFunction<OepRelationshipListReleaseNative, OepRelationshipListReleaseDart>(
            'oep_relationship_list_release',
          ),
      matchLocationToString = _library.lookupFunction<OepMatchLocationToStringNative, OepMatchLocationToStringDart>(
        'oep_match_location_to_string',
      ),
      searchRepository = _library.lookupFunction<OepSearchRepositoryNative, OepSearchRepositoryDart>(
        'oep_search_repository',
      ),
      repositorySearchResultRelease = _library
          .lookupFunction<OepRepositorySearchResultReleaseNative, OepRepositorySearchResultReleaseDart>(
            'oep_repository_search_result_release',
          ),
      searchObjects = _library.lookupFunction<OepSearchObjectsNative, OepSearchObjectsDart>('oep_search_objects'),
      objectSearchResultListRelease = _library
          .lookupFunction<OepObjectSearchResultListReleaseNative, OepObjectSearchResultListReleaseDart>(
            'oep_object_search_result_list_release',
          ),
      searchRelationships = _library.lookupFunction<OepSearchRelationshipsNative, OepSearchRelationshipsDart>(
        'oep_search_relationships',
      ),
      relationshipSearchResultListRelease = _library
          .lookupFunction<OepRelationshipSearchResultListReleaseNative, OepRelationshipSearchResultListReleaseDart>(
            'oep_relationship_search_result_list_release',
          ),
      objectCreate = _library.lookupFunction<OepObjectCreateNative, OepObjectCreateDart>('oep_object_create'),
      relationshipCreate = _library.lookupFunction<OepRelationshipCreateNative, OepRelationshipCreateDart>(
        'oep_relationship_create',
      ),
      transactionBegin = _library.lookupFunction<OepTransactionBeginNative, OepTransactionBeginDart>(
        'oep_transaction_begin',
      ),
      transactionCommit = _library.lookupFunction<OepTransactionCommitNative, OepTransactionCommitDart>(
        'oep_transaction_commit',
      ),
      transactionRollback = _library.lookupFunction<OepTransactionRollbackNative, OepTransactionRollbackDart>(
        'oep_transaction_rollback',
      ),
      transactionIsActive = _library.lookupFunction<OepTransactionIsActiveNative, OepTransactionIsActiveDart>(
        'oep_transaction_is_active',
      ),
      packageInstall = _library.lookupFunction<OepPackageInstallNative, OepPackageInstallDart>(
        'oep_package_install',
      ),
      packageListInstalled = _library
          .lookupFunction<OepPackageListInstalledNative, OepPackageListInstalledDart>(
            'oep_package_list_installed',
          ),
      installedPackageListRelease = _library
          .lookupFunction<OepInstalledPackageListReleaseNative, OepInstalledPackageListReleaseDart>(
            'oep_installed_package_list_release',
          ),
      packageGetInfo = _library.lookupFunction<OepPackageGetInfoNative, OepPackageGetInfoDart>(
        'oep_package_get_info',
      ),
      packageGetContents = _library.lookupFunction<OepPackageGetContentsNative, OepPackageGetContentsDart>(
        'oep_package_get_contents',
      ),
      packageLocate = _library.lookupFunction<OepPackageLocateNative, OepPackageLocateDart>(
        'oep_package_locate',
      ),
      packageVerify = _library.lookupFunction<OepPackageVerifyNative, OepPackageVerifyDart>(
        'oep_package_verify',
      ),
      packageSearch = _library.lookupFunction<OepPackageSearchNative, OepPackageSearchDart>(
        'oep_package_search',
      ),
      transactionGetInfo = _library.lookupFunction<OepTransactionGetInfoNative, OepTransactionGetInfoDart>(
        'oep_transaction_get_info',
      ),
      transactionHistory = _library.lookupFunction<OepTransactionHistoryNative, OepTransactionHistoryDart>(
        'oep_transaction_history',
      ),
      transactionRecordListRelease = _library
          .lookupFunction<OepTransactionRecordListReleaseNative, OepTransactionRecordListReleaseDart>(
            'oep_transaction_record_list_release',
          ),
      trustAddCertificate = _library.lookupFunction<OepTrustAddCertificateNative, OepTrustAddCertificateDart>(
        'oep_trust_add_certificate',
      ),
      trustGetCertificate = _library.lookupFunction<OepTrustGetCertificateNative, OepTrustGetCertificateDart>(
        'oep_trust_get_certificate',
      ),
      trustListCertificates = _library
          .lookupFunction<OepTrustListCertificatesNative, OepTrustListCertificatesDart>(
            'oep_trust_list_certificates',
          ),
      certificateListRelease = _library.lookupFunction<OepCertificateListReleaseNative, OepCertificateListReleaseDart>(
        'oep_certificate_list_release',
      ),
      trustRevokeCertificate = _library
          .lookupFunction<OepTrustRevokeCertificateNative, OepTrustRevokeCertificateDart>(
            'oep_trust_revoke_certificate',
          ),
      trustGetPolicy = _library.lookupFunction<OepTrustGetPolicyNative, OepTrustGetPolicyDart>(
        'oep_trust_get_policy',
      ),
      trustSetPolicy = _library.lookupFunction<OepTrustSetPolicyNative, OepTrustSetPolicyDart>(
        'oep_trust_set_policy',
      ),
      packageGetTrustStatus = _library
          .lookupFunction<OepPackageGetTrustStatusNative, OepPackageGetTrustStatusDart>(
            'oep_package_get_trust_status',
          ),
      dependencyStateToString = _library
          .lookupFunction<OepDependencyStateToStringNative, OepDependencyStateToStringDart>(
            'oep_dependency_state_to_string',
          ),
      dependencyEntryListRelease = _library
          .lookupFunction<OepDependencyEntryListReleaseNative, OepDependencyEntryListReleaseDart>(
            'oep_dependency_entry_list_release',
          ),
      packageIdListRelease = _library
          .lookupFunction<OepPackageIdListReleaseNative, OepPackageIdListReleaseDart>(
            'oep_package_id_list_release',
          ),
      packageResolveDependencies = _library
          .lookupFunction<OepPackageResolveDependenciesNative, OepPackageResolveDependenciesDart>(
            'oep_package_resolve_dependencies',
          ),
      eventTypeToString = _library.lookupFunction<OepEventTypeToStringNative, OepEventTypeToStringDart>(
        'oep_event_type_to_string',
      ),
      repositoryEventListRelease = _library
          .lookupFunction<OepRepositoryEventListReleaseNative, OepRepositoryEventListReleaseDart>(
            'oep_repository_event_list_release',
          ),
      runtimeRecentEvents = _library.lookupFunction<OepRuntimeRecentEventsNative, OepRuntimeRecentEventsDart>(
        'oep_runtime_recent_events',
      ),
      packageAnalyzeUninstallImpact = _library
          .lookupFunction<OepPackageAnalyzeUninstallImpactNative, OepPackageAnalyzeUninstallImpactDart>(
            'oep_package_analyze_uninstall_impact',
          ),
      packageUninstall = _library.lookupFunction<OepPackageUninstallNative, OepPackageUninstallDart>(
        'oep_package_uninstall',
      ),
      packageAnalyzeUpdateImpact = _library
          .lookupFunction<OepPackageAnalyzeUpdateImpactNative, OepPackageAnalyzeUpdateImpactDart>(
            'oep_package_analyze_update_impact',
          ),
      packageUpdate = _library.lookupFunction<OepPackageUpdateNative, OepPackageUpdateDart>(
        'oep_package_update',
      ),
      mergeConflictKindToString = _library
          .lookupFunction<OepMergeConflictKindToStringNative, OepMergeConflictKindToStringDart>(
            'oep_merge_conflict_kind_to_string',
          ),
      mergeConflictListRelease = _library
          .lookupFunction<OepMergeConflictListReleaseNative, OepMergeConflictListReleaseDart>(
            'oep_merge_conflict_list_release',
          ),
      repositoryPlanMerge = _library.lookupFunction<OepRepositoryPlanMergeNative, OepRepositoryPlanMergeDart>(
        'oep_repository_plan_merge',
      ),
      repositoryExecuteMerge = _library
          .lookupFunction<OepRepositoryExecuteMergeNative, OepRepositoryExecuteMergeDart>(
            'oep_repository_execute_merge',
          ),
      engineLoadObject = _library.lookupFunction<OepEngineLoadObjectNative, OepEngineLoadObjectDart>(
        'oep_engine_load_object',
      ),
      engineLoadGraph = _library.lookupFunction<OepEngineLoadGraphNative, OepEngineLoadGraphDart>(
        'oep_engine_load_graph',
      ),
      engineQuery = _library.lookupFunction<OepEngineQueryNative, OepEngineQueryDart>('oep_engine_query'),
      engineTraverse = _library.lookupFunction<OepEngineTraverseNative, OepEngineTraverseDart>(
        'oep_engine_traverse',
      ),
      engineRelatedObjects = _library.lookupFunction<OepEngineRelatedObjectsNative, OepEngineRelatedObjectsDart>(
        'oep_engine_related_objects',
      ),
      engineDependencyGraph = _library
          .lookupFunction<OepEngineDependencyGraphNative, OepEngineDependencyGraphDart>(
            'oep_engine_dependency_graph',
          ),
      kgeBuildGraph = _library.lookupFunction<OepKgeBuildGraphNative, OepKgeBuildGraphDart>('oep_kge_build_graph'),
      kgeRefreshGraph = _library.lookupFunction<OepKgeRefreshGraphNative, OepKgeRefreshGraphDart>(
        'oep_kge_refresh_graph',
      ),
      graphIssueKindToString = _library
          .lookupFunction<OepGraphIssueKindToStringNative, OepGraphIssueKindToStringDart>(
            'oep_graph_issue_kind_to_string',
          ),
      graphIssueListRelease = _library.lookupFunction<OepGraphIssueListReleaseNative, OepGraphIssueListReleaseDart>(
        'oep_graph_issue_list_release',
      ),
      kgeValidateGraph = _library.lookupFunction<OepKgeValidateGraphNative, OepKgeValidateGraphDart>(
        'oep_kge_validate_graph',
      ),
      kgeGraphStatistics = _library.lookupFunction<OepKgeGraphStatisticsNative, OepKgeGraphStatisticsDart>(
        'oep_kge_graph_statistics',
      ),
      componentMembershipListRelease = _library
          .lookupFunction<OepComponentMembershipListReleaseNative, OepComponentMembershipListReleaseDart>(
            'oep_component_membership_list_release',
          ),
      kgeConnectedComponents = _library
          .lookupFunction<OepKgeConnectedComponentsNative, OepKgeConnectedComponentsDart>(
            'oep_kge_connected_components',
          ),
      kgeShortestPath = _library.lookupFunction<OepKgeShortestPathNative, OepKgeShortestPathDart>(
        'oep_kge_shortest_path',
      ),
      kgeSubgraph = _library.lookupFunction<OepKgeSubgraphNative, OepKgeSubgraphDart>('oep_kge_subgraph'),
      stringRelease = _library.lookupFunction<OepStringReleaseNative, OepStringReleaseDart>('oep_string_release'),
      kgeExportJson = _library.lookupFunction<OepKgeExportJsonNative, OepKgeExportJsonDart>('oep_kge_export_json'),
      kgeExportGraphmlPlaceholder = _library
          .lookupFunction<OepKgeExportGraphmlPlaceholderNative, OepKgeExportGraphmlPlaceholderDart>(
            'oep_kge_export_graphml_placeholder',
          ),
      queryCategoryToString = _library.lookupFunction<OepQueryCategoryToStringNative, OepQueryCategoryToStringDart>(
        'oep_query_category_to_string',
      ),
      eqePlanQuery = _library.lookupFunction<OepEqePlanQueryNative, OepEqePlanQueryDart>('oep_eqe_plan_query'),
      eqeExecuteQuery = _library.lookupFunction<OepEqeExecuteQueryNative, OepEqeExecuteQueryDart>(
        'oep_eqe_execute_query',
      ),
      eqeQueryStatistics = _library.lookupFunction<OepEqeQueryStatisticsNative, OepEqeQueryStatisticsDart>(
        'oep_eqe_query_statistics',
      ),
      eqeClearQueryCache = _library.lookupFunction<OepEqeClearQueryCacheNative, OepEqeClearQueryCacheDart>(
        'oep_eqe_clear_query_cache',
      ),
      eqeQueryCacheInfo = _library.lookupFunction<OepEqeQueryCacheInfoNative, OepEqeQueryCacheInfoDart>(
        'oep_eqe_query_cache_info',
      ),
      ruleCategoryToString = _library.lookupFunction<OepRuleCategoryToStringNative, OepRuleCategoryToStringDart>(
        'oep_rule_category_to_string',
      ),
      ruleSeverityToString = _library.lookupFunction<OepRuleSeverityToStringNative, OepRuleSeverityToStringDart>(
        'oep_rule_severity_to_string',
      ),
      ruleScopeKindToString = _library
          .lookupFunction<OepRuleScopeKindToStringNative, OepRuleScopeKindToStringDart>(
            'oep_rule_scope_kind_to_string',
          ),
      ruleConditionKindToString = _library
          .lookupFunction<OepRuleConditionKindToStringNative, OepRuleConditionKindToStringDart>(
            'oep_rule_condition_kind_to_string',
          ),
      ruleEvaluationStatusToString = _library
          .lookupFunction<OepRuleEvaluationStatusToStringNative, OepRuleEvaluationStatusToStringDart>(
            'oep_rule_evaluation_status_to_string',
          ),
      ruleConditionListRelease = _library
          .lookupFunction<OepRuleConditionListReleaseNative, OepRuleConditionListReleaseDart>(
            'oep_rule_condition_list_release',
          ),
      ruleDiagnosticListRelease = _library
          .lookupFunction<OepRuleDiagnosticListReleaseNative, OepRuleDiagnosticListReleaseDart>(
            'oep_rule_diagnostic_list_release',
          ),
      ruleEvaluationSummaryListRelease = _library
          .lookupFunction<OepRuleEvaluationSummaryListReleaseNative, OepRuleEvaluationSummaryListReleaseDart>(
            'oep_rule_evaluation_summary_list_release',
          ),
      rulesRegister = _library.lookupFunction<OepRulesRegisterNative, OepRulesRegisterDart>(
        'oep_rules_register',
      ),
      rulesRemove = _library.lookupFunction<OepRulesRemoveNative, OepRulesRemoveDart>('oep_rules_remove'),
      rulesEnable = _library.lookupFunction<OepRulesEnableNative, OepRulesEnableDart>('oep_rules_enable'),
      rulesDisable = _library.lookupFunction<OepRulesDisableNative, OepRulesDisableDart>('oep_rules_disable'),
      rulesListAll = _library.lookupFunction<OepRulesListAllNative, OepRulesListAllDart>('oep_rules_list_all'),
      rulesListEnabled = _library.lookupFunction<OepRulesListEnabledNative, OepRulesListEnabledDart>(
        'oep_rules_list_enabled',
      ),
      rulesListDisabled = _library.lookupFunction<OepRulesListDisabledNative, OepRulesListDisabledDart>(
        'oep_rules_list_disabled',
      ),
      rulesGet = _library.lookupFunction<OepRulesGetNative, OepRulesGetDart>('oep_rules_get'),
      rulesEvaluate = _library.lookupFunction<OepRulesEvaluateNative, OepRulesEvaluateDart>(
        'oep_rules_evaluate',
      ),
      rulesEvaluateAll = _library.lookupFunction<OepRulesEvaluateAllNative, OepRulesEvaluateAllDart>(
        'oep_rules_evaluate_all',
      ),
      validationProfileToString = _library
          .lookupFunction<OepValidationProfileToStringNative, OepValidationProfileToStringDart>(
            'oep_validation_profile_to_string',
          ),
      validationFindingListRelease = _library
          .lookupFunction<OepValidationFindingListReleaseNative, OepValidationFindingListReleaseDart>(
            'oep_validation_finding_list_release',
          ),
      validationCreateSession = _library
          .lookupFunction<OepValidationCreateSessionNative, OepValidationCreateSessionDart>(
            'oep_validation_create_session',
          ),
      validationValidateObject = _library
          .lookupFunction<OepValidationValidateObjectNative, OepValidationValidateObjectDart>(
            'oep_validation_validate_object',
          ),
      validationValidateObjects = _library
          .lookupFunction<OepValidationValidateObjectsNative, OepValidationValidateObjectsDart>(
            'oep_validation_validate_objects',
          ),
      validationValidateContext = _library
          .lookupFunction<OepValidationValidateContextNative, OepValidationValidateContextDart>(
            'oep_validation_validate_context',
          ),
      validationValidatePackage = _library
          .lookupFunction<OepValidationValidatePackageNative, OepValidationValidatePackageDart>(
            'oep_validation_validate_package',
          ),
      validationReport = _library.lookupFunction<OepValidationReportNative, OepValidationReportDart>(
        'oep_validation_report',
      ),
      validationStatistics = _library
          .lookupFunction<OepValidationStatisticsFnNative, OepValidationStatisticsFnDart>(
            'oep_validation_statistics',
          ),
      analysisDependencies = _library.lookupFunction<OepAnalysisDependenciesNative, OepAnalysisDependenciesDart>(
        'oep_analysis_dependencies',
      ),
      analysisImpact = _library.lookupFunction<OepAnalysisImpactNative, OepAnalysisImpactDart>(
        'oep_analysis_impact',
      ),
      analysisReachability = _library
          .lookupFunction<OepAnalysisReachabilityNative, OepAnalysisReachabilityDart>(
            'oep_analysis_reachability',
          ),
      analysisRootCause = _library.lookupFunction<OepAnalysisRootCauseNative, OepAnalysisRootCauseDart>(
        'oep_analysis_root_cause',
      ),
      reasoningCreateSession = _library
          .lookupFunction<OepReasoningCreateSessionNative, OepReasoningCreateSessionDart>(
            'oep_reasoning_create_session',
          ),
      reasoningExecute = _library.lookupFunction<OepReasoningExecuteNative, OepReasoningExecuteDart>(
        'oep_reasoning_execute',
      ),
      reasoningReport = _library.lookupFunction<OepReasoningReportNative, OepReasoningReportDart>(
        'oep_reasoning_report',
      ),
      reasoningRecommendations = _library
          .lookupFunction<OepReasoningRecommendationsNative, OepReasoningRecommendationsDart>(
            'oep_reasoning_recommendations',
          ),
      reasoningGetConclusion = _library
          .lookupFunction<OepReasoningGetConclusionNative, OepReasoningGetConclusionDart>(
            'oep_reasoning_get_conclusion',
          ),
      recommendationKindToString = _library
          .lookupFunction<OepRecommendationKindToStringNative, OepRecommendationKindToStringDart>(
            'oep_recommendation_kind_to_string',
          ),
      reasoningGetRecommendation = _library
          .lookupFunction<OepReasoningGetRecommendationNative, OepReasoningGetRecommendationDart>(
            'oep_reasoning_get_recommendation',
          ),
      reasoningGetEvidenceNode = _library
          .lookupFunction<OepReasoningGetEvidenceNodeNative, OepReasoningGetEvidenceNodeDart>(
            'oep_reasoning_get_evidence_node',
          ),
      workflowKindToString = _library.lookupFunction<OepWorkflowKindToStringNative, OepWorkflowKindToStringDart>(
        'oep_workflow_kind_to_string',
      ),
      inspectionTargetKindToString = _library
          .lookupFunction<OepInspectionTargetKindToStringNative, OepInspectionTargetKindToStringDart>(
            'oep_inspection_target_kind_to_string',
          ),
      eipCreateSession = _library.lookupFunction<OepEipCreateSessionNative, OepEipCreateSessionDart>(
        'oep_eip_create_session',
      ),
      eipResumeSession = _library.lookupFunction<OepEipResumeSessionNative, OepEipResumeSessionDart>(
        'oep_eip_resume_session',
      ),
      eipCloneSession = _library.lookupFunction<OepEipCloneSessionNative, OepEipCloneSessionDart>(
        'oep_eip_clone_session',
      ),
      eipCloseSession = _library.lookupFunction<OepEipCloseSessionNative, OepEipCloseSessionDart>(
        'oep_eip_close_session',
      ),
      eipSwitchSession = _library.lookupFunction<OepEipSwitchSessionNative, OepEipSwitchSessionDart>(
        'oep_eip_switch_session',
      ),
      eipListSessions = _library.lookupFunction<OepEipListSessionsNative, OepEipListSessionsDart>(
        'oep_eip_list_sessions',
      ),
      eipGetSession = _library.lookupFunction<OepEipGetSessionNative, OepEipGetSessionDart>('oep_eip_get_session'),
      eipExportSessionSummary = _library
          .lookupFunction<OepEipExportSessionSummaryNative, OepEipExportSessionSummaryDart>(
            'oep_eip_export_session_summary',
          ),
      eipQuery = _library.lookupFunction<OepEipQueryNative, OepEipQueryDart>('oep_eip_query'),
      eipInspect = _library.lookupFunction<OepEipInspectNative, OepEipInspectDart>('oep_eip_inspect'),
      eipValidate = _library.lookupFunction<OepEipValidateNative, OepEipValidateDart>('oep_eip_validate'),
      eipAnalyze = _library.lookupFunction<OepEipAnalyzeNative, OepEipAnalyzeDart>('oep_eip_analyze'),
      eipReason = _library.lookupFunction<OepEipReasonNative, OepEipReasonDart>('oep_eip_reason'),
      eipRecommend = _library.lookupFunction<OepEipRecommendNative, OepEipRecommendDart>('oep_eip_recommend'),
      eipEngineeringSummary = _library
          .lookupFunction<OepEipEngineeringSummaryNative, OepEipEngineeringSummaryDart>(
            'oep_eip_engineering_summary',
          ),
      eipEngineeringHealth = _library
          .lookupFunction<OepEipEngineeringHealthNative, OepEipEngineeringHealthDart>(
            'oep_eip_engineering_health',
          ),
      eipEngineeringRecommendations = _library
          .lookupFunction<OepEipEngineeringRecommendationsNative, OepEipEngineeringRecommendationsDart>(
            'oep_eip_engineering_recommendations',
          ),
      eipRuntimeMetrics = _library.lookupFunction<OepEipRuntimeMetricsNative, OepEipRuntimeMetricsDart>(
        'oep_eip_runtime_metrics',
      ),
      eipInvalidateCaches = _library.lookupFunction<OepEipInvalidateCachesNative, OepEipInvalidateCachesDart>(
        'oep_eip_invalidate_caches',
      ),
      eipCleanup = _library.lookupFunction<OepEipCleanupNative, OepEipCleanupDart>('oep_eip_cleanup');

  // ignore: unused_field
  final DynamicLibrary _library;

  final OepFoundationVersionDart foundationVersion;
  final OepApiVersionDart apiVersion;
  final OepAbiVersionDart abiVersion;
  final OepRuntimeStateToStringDart runtimeStateToString;
  final OepErrorCodeToStringDart errorCodeToString;
  final OepErrorCategoryToStringDart errorCategoryToString;
  final OepRuntimeCreateDart runtimeCreate;
  final OepRuntimeDestroyDart runtimeDestroy;
  final OepRuntimeInitializeDart runtimeInitialize;
  final OepRuntimeOpenRepositoryDart runtimeOpenRepository;
  final OepRuntimeCloseRepositoryDart runtimeCloseRepository;
  final OepRuntimeShutdownDart runtimeShutdown;
  final OepRuntimeGetStateDart runtimeGetState;
  final OepRuntimeGetRepositoryStatusDart runtimeGetRepositoryStatus;
  final OepObjectTypeToStringDart objectTypeToString;
  final OepObjectStoreGetCountDart objectStoreGetCount;
  final OepObjectStoreGetByIdDart objectStoreGetById;
  final OepObjectStoreListDart objectStoreList;
  final OepObjectListReleaseDart objectListRelease;
  final OepRuntimeGetRepositoryStatisticsDart runtimeGetRepositoryStatistics;
  final OepRelationshipTypeToStringDart relationshipTypeToString;
  final OepRelationshipStoreGetCountDart relationshipStoreGetCount;
  final OepRelationshipStoreGetByIdDart relationshipStoreGetById;
  final OepRelationshipStoreListDart relationshipStoreList;
  final OepRelationshipListReleaseDart relationshipListRelease;
  final OepMatchLocationToStringDart matchLocationToString;
  final OepSearchRepositoryDart searchRepository;
  final OepRepositorySearchResultReleaseDart repositorySearchResultRelease;
  final OepSearchObjectsDart searchObjects;
  final OepObjectSearchResultListReleaseDart objectSearchResultListRelease;
  final OepSearchRelationshipsDart searchRelationships;
  final OepRelationshipSearchResultListReleaseDart relationshipSearchResultListRelease;
  final OepObjectCreateDart objectCreate;
  final OepRelationshipCreateDart relationshipCreate;
  final OepTransactionBeginDart transactionBegin;
  final OepTransactionCommitDart transactionCommit;
  final OepTransactionRollbackDart transactionRollback;
  final OepTransactionIsActiveDart transactionIsActive;
  final OepPackageInstallDart packageInstall;
  final OepPackageListInstalledDart packageListInstalled;
  final OepInstalledPackageListReleaseDart installedPackageListRelease;
  final OepPackageGetInfoDart packageGetInfo;
  final OepPackageGetContentsDart packageGetContents;
  final OepPackageLocateDart packageLocate;
  final OepPackageVerifyDart packageVerify;
  final OepPackageSearchDart packageSearch;
  final OepTransactionGetInfoDart transactionGetInfo;
  final OepTransactionHistoryDart transactionHistory;
  final OepTransactionRecordListReleaseDart transactionRecordListRelease;
  final OepTrustAddCertificateDart trustAddCertificate;
  final OepTrustGetCertificateDart trustGetCertificate;
  final OepTrustListCertificatesDart trustListCertificates;
  final OepCertificateListReleaseDart certificateListRelease;
  final OepTrustRevokeCertificateDart trustRevokeCertificate;
  final OepTrustGetPolicyDart trustGetPolicy;
  final OepTrustSetPolicyDart trustSetPolicy;
  final OepPackageGetTrustStatusDart packageGetTrustStatus;
  final OepDependencyStateToStringDart dependencyStateToString;
  final OepDependencyEntryListReleaseDart dependencyEntryListRelease;
  final OepPackageIdListReleaseDart packageIdListRelease;
  final OepPackageResolveDependenciesDart packageResolveDependencies;
  final OepEventTypeToStringDart eventTypeToString;
  final OepRepositoryEventListReleaseDart repositoryEventListRelease;
  final OepRuntimeRecentEventsDart runtimeRecentEvents;
  final OepPackageAnalyzeUninstallImpactDart packageAnalyzeUninstallImpact;
  final OepPackageUninstallDart packageUninstall;
  final OepPackageAnalyzeUpdateImpactDart packageAnalyzeUpdateImpact;
  final OepPackageUpdateDart packageUpdate;
  final OepMergeConflictKindToStringDart mergeConflictKindToString;
  final OepMergeConflictListReleaseDart mergeConflictListRelease;
  final OepRepositoryPlanMergeDart repositoryPlanMerge;
  final OepRepositoryExecuteMergeDart repositoryExecuteMerge;
  final OepEngineLoadObjectDart engineLoadObject;
  final OepEngineLoadGraphDart engineLoadGraph;
  final OepEngineQueryDart engineQuery;
  final OepEngineTraverseDart engineTraverse;
  final OepEngineRelatedObjectsDart engineRelatedObjects;
  final OepEngineDependencyGraphDart engineDependencyGraph;
  final OepKgeBuildGraphDart kgeBuildGraph;
  final OepKgeRefreshGraphDart kgeRefreshGraph;
  final OepGraphIssueKindToStringDart graphIssueKindToString;
  final OepGraphIssueListReleaseDart graphIssueListRelease;
  final OepKgeValidateGraphDart kgeValidateGraph;
  final OepKgeGraphStatisticsDart kgeGraphStatistics;
  final OepComponentMembershipListReleaseDart componentMembershipListRelease;
  final OepKgeConnectedComponentsDart kgeConnectedComponents;
  final OepKgeShortestPathDart kgeShortestPath;
  final OepKgeSubgraphDart kgeSubgraph;
  final OepStringReleaseDart stringRelease;
  final OepKgeExportJsonDart kgeExportJson;
  final OepKgeExportGraphmlPlaceholderDart kgeExportGraphmlPlaceholder;
  final OepQueryCategoryToStringDart queryCategoryToString;
  final OepEqePlanQueryDart eqePlanQuery;
  final OepEqeExecuteQueryDart eqeExecuteQuery;
  final OepEqeQueryStatisticsDart eqeQueryStatistics;
  final OepEqeClearQueryCacheDart eqeClearQueryCache;
  final OepEqeQueryCacheInfoDart eqeQueryCacheInfo;
  final OepRuleCategoryToStringDart ruleCategoryToString;
  final OepRuleSeverityToStringDart ruleSeverityToString;
  final OepRuleScopeKindToStringDart ruleScopeKindToString;
  final OepRuleConditionKindToStringDart ruleConditionKindToString;
  final OepRuleEvaluationStatusToStringDart ruleEvaluationStatusToString;
  final OepRuleConditionListReleaseDart ruleConditionListRelease;
  final OepRuleDiagnosticListReleaseDart ruleDiagnosticListRelease;
  final OepRuleEvaluationSummaryListReleaseDart ruleEvaluationSummaryListRelease;
  final OepRulesRegisterDart rulesRegister;
  final OepRulesRemoveDart rulesRemove;
  final OepRulesEnableDart rulesEnable;
  final OepRulesDisableDart rulesDisable;
  final OepRulesListAllDart rulesListAll;
  final OepRulesListEnabledDart rulesListEnabled;
  final OepRulesListDisabledDart rulesListDisabled;
  final OepRulesGetDart rulesGet;
  final OepRulesEvaluateDart rulesEvaluate;
  final OepRulesEvaluateAllDart rulesEvaluateAll;
  final OepValidationProfileToStringDart validationProfileToString;
  final OepValidationFindingListReleaseDart validationFindingListRelease;
  final OepValidationCreateSessionDart validationCreateSession;
  final OepValidationValidateObjectDart validationValidateObject;
  final OepValidationValidateObjectsDart validationValidateObjects;
  final OepValidationValidateContextDart validationValidateContext;
  final OepValidationValidatePackageDart validationValidatePackage;
  final OepValidationReportDart validationReport;
  final OepValidationStatisticsFnDart validationStatistics;
  final OepAnalysisDependenciesDart analysisDependencies;
  final OepAnalysisImpactDart analysisImpact;
  final OepAnalysisReachabilityDart analysisReachability;
  final OepAnalysisRootCauseDart analysisRootCause;
  final OepReasoningCreateSessionDart reasoningCreateSession;
  final OepReasoningExecuteDart reasoningExecute;
  final OepReasoningReportDart reasoningReport;
  final OepReasoningRecommendationsDart reasoningRecommendations;
  final OepReasoningGetConclusionDart reasoningGetConclusion;
  final OepRecommendationKindToStringDart recommendationKindToString;
  final OepReasoningGetRecommendationDart reasoningGetRecommendation;
  final OepReasoningGetEvidenceNodeDart reasoningGetEvidenceNode;
  final OepWorkflowKindToStringDart workflowKindToString;
  final OepInspectionTargetKindToStringDart inspectionTargetKindToString;
  final OepEipCreateSessionDart eipCreateSession;
  final OepEipResumeSessionDart eipResumeSession;
  final OepEipCloneSessionDart eipCloneSession;
  final OepEipCloseSessionDart eipCloseSession;
  final OepEipSwitchSessionDart eipSwitchSession;
  final OepEipListSessionsDart eipListSessions;
  final OepEipGetSessionDart eipGetSession;
  final OepEipExportSessionSummaryDart eipExportSessionSummary;
  final OepEipQueryDart eipQuery;
  final OepEipInspectDart eipInspect;
  final OepEipValidateDart eipValidate;
  final OepEipAnalyzeDart eipAnalyze;
  final OepEipReasonDart eipReason;
  final OepEipRecommendDart eipRecommend;
  final OepEipEngineeringSummaryDart eipEngineeringSummary;
  final OepEipEngineeringHealthDart eipEngineeringHealth;
  final OepEipEngineeringRecommendationsDart eipEngineeringRecommendations;
  final OepEipRuntimeMetricsDart eipRuntimeMetrics;
  final OepEipInvalidateCachesDart eipInvalidateCaches;
  final OepEipCleanupDart eipCleanup;
}

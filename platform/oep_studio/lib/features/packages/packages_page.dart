import 'package:flutter/material.dart';

import 'package_manager_page.dart';

/// Route target for [StudioDestination.packages] — was a
/// [PlaceholderWorkspace] stub; now the real Package Integration UI
/// (AP-DS-002): Install Package, Package Metadata, Publisher Metadata,
/// and Package Validation over the currently open repository. See
/// [PackageManagerPage] for the implementation.
class PackagesPage extends StatelessWidget {
  const PackagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PackageManagerPage();
  }
}

import 'package:flutter/material.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/core/theme/app_theme.dart';

/// Definition for each navigation destination (studio/module).
class NavDestination {
  final StudioType studio;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Color accentColor;

  const NavDestination({
    required this.studio,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.accentColor,
  });
}

/// All navigation destinations in display order.
const List<NavDestination> navDestinations = [
  NavDestination(
    studio: StudioType.pdfStudio,
    label: 'PDF',
    icon: Icons.picture_as_pdf_outlined,
    selectedIcon: Icons.picture_as_pdf,
    accentColor: AppTheme.pdfStudioColor,
  ),
  NavDestination(
    studio: StudioType.documentStudio,
    label: 'Docs',
    icon: Icons.description_outlined,
    selectedIcon: Icons.description,
    accentColor: AppTheme.documentStudioColor,
  ),
  NavDestination(
    studio: StudioType.imageStudio,
    label: 'Image',
    icon: Icons.image_outlined,
    selectedIcon: Icons.image,
    accentColor: AppTheme.imageStudioColor,
  ),
  NavDestination(
    studio: StudioType.videoStudio,
    label: 'Video',
    icon: Icons.videocam_outlined,
    selectedIcon: Icons.videocam,
    accentColor: AppTheme.videoStudioColor,
  ),
  NavDestination(
    studio: StudioType.audioStudio,
    label: 'Audio',
    icon: Icons.audiotrack_outlined,
    selectedIcon: Icons.audiotrack,
    accentColor: AppTheme.audioStudioColor,
  ),
];

/// Secondary navigation destinations (system/management modules).
const List<NavDestination> secondaryDestinations = [
  NavDestination(
    studio: StudioType.storageManager,
    label: 'Storage',
    icon: Icons.storage_outlined,
    selectedIcon: Icons.storage,
    accentColor: AppTheme.storageColor,
  ),
  NavDestination(
    studio: StudioType.fileInspector,
    label: 'Inspector',
    icon: Icons.search_outlined,
    selectedIcon: Icons.search,
    accentColor: AppTheme.inspectorColor,
  ),
  NavDestination(
    studio: StudioType.processingManager,
    label: 'Jobs',
    icon: Icons.pending_actions_outlined,
    selectedIcon: Icons.pending_actions,
    accentColor: AppTheme.processingColor,
  ),
  NavDestination(
    studio: StudioType.dependencyManager,
    label: 'System',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    accentColor: AppTheme.dependencyColor,
  ),
];

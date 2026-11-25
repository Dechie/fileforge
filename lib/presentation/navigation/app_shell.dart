import 'package:flutter/material.dart';
import 'package:fileforge/core/theme/app_theme.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/presentation/navigation/nav_destinations.dart';
import 'package:fileforge/presentation/navigation/shell_scope.dart';
import 'package:fileforge/presentation/screens/audio_studio_screen.dart';
import 'package:fileforge/presentation/screens/document_studio_screen.dart';
import 'package:fileforge/presentation/screens/file_inspector_screen.dart';
import 'package:fileforge/presentation/screens/home_screen.dart';
import 'package:fileforge/presentation/screens/image_studio_screen.dart';
import 'package:fileforge/presentation/screens/jobs_screen.dart';
import 'package:fileforge/presentation/screens/pdf_studio_screen.dart';
import 'package:fileforge/presentation/screens/storage_screen.dart';
import 'package:fileforge/presentation/screens/system_screen.dart';
import 'package:fileforge/presentation/screens/video_studio_screen.dart';

/// Adaptive app shell: NavigationRail on desktop, BottomNavigationBar on mobile.
///
/// The dashboard is the landing view. Studio and system screens stay mounted
/// so a selection survives switching sections.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  bool _showSecondary = false;
  bool _showHome = true;

  List<NavDestination> get _currentDestinations =>
      _showSecondary ? secondaryDestinations : navDestinations;

  void _openHome() {
    setState(() {
      _showHome = true;
      _showSecondary = false;
    });
  }

  void _openStudio(StudioType studio) {
    final index = navDestinations.indexWhere((item) => item.studio == studio);
    if (index < 0) return;
    setState(() {
      _showSecondary = false;
      _showHome = false;
      _selectedIndex = index;
    });
  }

  void _openDestination(StudioType studio, {required bool secondary}) {
    final destinations = secondary ? secondaryDestinations : navDestinations;
    final index = destinations.indexWhere((item) => item.studio == studio);
    setState(() {
      _showSecondary = secondary;
      _showHome = false;
      _selectedIndex = index < 0 ? 0 : index;
    });
  }

  int _contentIndex() {
    if (_showHome && !_showSecondary) return 0;
    final destinations = _currentDestinations;
    final index = _selectedIndex.clamp(0, destinations.length - 1);
    return _screenIndex(destinations[index].studio);
  }

  int _screenIndex(StudioType studio) {
    switch (studio) {
      case StudioType.pdfStudio:
        return 1;
      case StudioType.documentStudio:
        return 2;
      case StudioType.imageStudio:
        return 3;
      case StudioType.videoStudio:
        return 4;
      case StudioType.audioStudio:
        return 5;
      case StudioType.storageManager:
        return 6;
      case StudioType.fileInspector:
        return 7;
      case StudioType.processingManager:
        return 8;
      case StudioType.dependencyManager:
        return 9;
      case StudioType.engineManager:
        return 9;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 800;
    return ShellScope(
      compact: !isWide,
      openStudio: _openStudio,
      openHome: _openHome,
      openSystem:
          () => _openDestination(StudioType.dependencyManager, secondary: true),
      openJobs:
          () => _openDestination(StudioType.processingManager, secondary: true),
      child: Scaffold(
        body: isWide ? _buildWideLayout() : _buildNarrowLayout(),
        bottomNavigationBar: isWide ? null : _buildBottomNav(),
      ),
    );
  }

  Widget _buildWideLayout() {
    final selected = _showHome ? null : _selectedIndex;
    return Row(
      children: [
        NavigationRail(
          selectedIndex: selected,
          onDestinationSelected: (index) {
            setState(() {
              _showHome = false;
              _selectedIndex = index;
            });
          },
          labelType: NavigationRailLabelType.all,
          leading: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Tooltip(
              message: 'Home',
              child: InkWell(
                onTap: _openHome,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Icon(
                        Icons.construction,
                        color: AppTheme.primaryColor,
                        size: 28,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'FileForge',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          trailing: Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: IconButton(
                  icon: Icon(
                    _showSecondary ? Icons.apps : Icons.tune,
                    color: AppTheme.textMuted,
                  ),
                  onPressed: () {
                    setState(() {
                      _showSecondary = !_showSecondary;
                      _showHome = false;
                      _selectedIndex = 0;
                    });
                  },
                  tooltip: _showSecondary ? 'Studios' : 'System',
                ),
              ),
            ),
          ),
          destinations:
              _currentDestinations
                  .map(
                    (destination) => NavigationRailDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(
                        destination.selectedIcon,
                        color: destination.accentColor,
                      ),
                      label: Text(destination.label),
                    ),
                  )
                  .toList(),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return _buildContent();
  }

  Widget _buildBottomNav() {
    if (!_showSecondary) {
      return BottomNavigationBar(
        currentIndex: _showHome ? 0 : _selectedIndex + 1,
        onTap: (index) {
          setState(() {
            if (index == 0) {
              _showHome = true;
            } else {
              _showHome = false;
              _selectedIndex = index - 1;
            }
          });
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          ...navDestinations.map(
            (destination) => BottomNavigationBarItem(
              icon: Icon(destination.icon),
              activeIcon: Icon(
                destination.selectedIcon,
                color: destination.accentColor,
              ),
              label: destination.label,
            ),
          ),
        ],
      );
    }
    return BottomNavigationBar(
      currentIndex: _selectedIndex.clamp(0, secondaryDestinations.length - 1),
      onTap: (index) => setState(() => _selectedIndex = index),
      items:
          secondaryDestinations
              .map(
                (destination) => BottomNavigationBarItem(
                  icon: Icon(destination.icon),
                  activeIcon: Icon(
                    destination.selectedIcon,
                    color: destination.accentColor,
                  ),
                  label: destination.label,
                ),
              )
              .toList(),
    );
  }

  Widget _buildContent() {
    return IndexedStack(
      index: _contentIndex(),
      children: const [
        HomeScreen(),
        PdfStudioScreen(),
        DocumentStudioScreen(),
        ImageStudioScreen(),
        VideoStudioScreen(),
        AudioStudioScreen(),
        StorageScreen(),
        FileInspectorScreen(),
        JobsScreen(),
        SystemScreen(),
      ],
    );
  }
}

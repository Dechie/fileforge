import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fileforge/application/providers/settings_provider.dart';
import 'package:fileforge/core/constants/app_constants.dart';
import 'package:fileforge/presentation/widgets/section_header.dart';

/// User preferences. Pushed on top of the shell from the dashboard.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SectionHeader(title: 'Appearance'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: settings.isDarkMode,
            onChanged: settings.setDarkMode,
          ),
          const SectionHeader(title: 'Processing Defaults'),
          ListTile(
            title: Text(
              'Video Quality (CRF) · ${settings.defaultVideoQuality}',
            ),
            subtitle: Slider(
              value: settings.defaultVideoQuality.toDouble(),
              min: 0,
              max: 51,
              divisions: 51,
              label: '${settings.defaultVideoQuality}',
              onChanged:
                  (value) => settings.setDefaultVideoQuality(value.round()),
            ),
          ),
          ListTile(
            title: Text('Image Quality · ${settings.defaultImageQuality}'),
            subtitle: Slider(
              value: settings.defaultImageQuality.toDouble(),
              min: 1,
              max: 100,
              divisions: 99,
              label: '${settings.defaultImageQuality}',
              onChanged:
                  (value) => settings.setDefaultImageQuality(value.round()),
            ),
          ),
          SwitchListTile(
            title: const Text('Preserve metadata by default'),
            value: settings.preserveMetadata,
            onChanged: settings.setPreserveMetadata,
          ),
          SwitchListTile(
            title: const Text('Remove GPS data by default'),
            value: settings.removeGpsData,
            onChanged: settings.setRemoveGpsData,
          ),
          const SectionHeader(title: 'Storage'),
          SwitchListTile(
            title: const Text('Auto-clean temp files after job completion'),
            value: settings.autoCleanTempFiles,
            onChanged: settings.setAutoCleanTempFiles,
          ),
          ListTile(
            title: const Text('Max concurrent jobs'),
            trailing: DropdownButton<int>(
              value: settings.maxConcurrentJobs,
              items: [
                for (var count = 1; count <= 8; count++)
                  DropdownMenuItem(value: count, child: Text('$count')),
              ],
              onChanged: (value) {
                if (value != null) settings.setMaxConcurrentJobs(value);
              },
            ),
          ),
          const SectionHeader(title: 'About'),
          ListTile(
            title: Text('FileForge v${AppConstants.appVersion}'),
            subtitle: const Text('Open source licenses'),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: AppConstants.appName,
                applicationVersion: AppConstants.appVersion,
              );
            },
          ),
        ],
      ),
    );
  }
}

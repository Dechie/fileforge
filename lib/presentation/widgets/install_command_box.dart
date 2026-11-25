import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fileforge/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// A monospace box displaying a terminal command with a copy button.
///
/// Used in the Dependency Manager to show install instructions.
class InstallCommandBox extends StatelessWidget {
  final String command;
  final VoidCallback? onCopy;

  const InstallCommandBox({super.key, required this.command, this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.terminal, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              command,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            color: AppTheme.textMuted,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: command));
              onCopy?.call();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Copy command',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

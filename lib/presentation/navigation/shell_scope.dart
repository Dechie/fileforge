import 'package:flutter/material.dart';
import 'package:fileforge/domain/enums/enums.dart';

/// Navigation actions shared by screens that live inside [AppShell].
class ShellScope extends InheritedWidget {
  const ShellScope({
    super.key,
    required this.compact,
    required this.openStudio,
    required this.openHome,
    required this.openSystem,
    required this.openJobs,
    required super.child,
  });

  /// True when the shell is using the bottom navigation layout.
  final bool compact;

  final ValueChanged<StudioType> openStudio;
  final VoidCallback openHome;
  final VoidCallback openSystem;
  final VoidCallback openJobs;

  static ShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShellScope>();
  }

  static ShellScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'ShellScope is missing above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(ShellScope oldWidget) => compact != oldWidget.compact;
}

/// App bar used by studio and system screens.
///
/// On a narrow layout the leading control returns to the dashboard.
AppBar forgeAppBar(
  BuildContext context, {
  required String title,
  List<Widget>? actions,
}) {
  final shell = ShellScope.maybeOf(context);
  final showHome = shell != null && shell.compact;
  return AppBar(
    automaticallyImplyLeading: false,
    leading:
        showHome
            ? IconButton(
              tooltip: 'Home',
              onPressed: shell.openHome,
              icon: const Icon(Icons.home_outlined),
            )
            : null,
    title: Text(title),
    actions: actions,
  );
}

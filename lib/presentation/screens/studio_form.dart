import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:fileforge/application/output_library.dart';
import 'package:fileforge/application/output_paths.dart';
import 'package:fileforge/application/providers/engine_provider.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:fileforge/domain/models/models.dart';
import 'package:fileforge/presentation/widgets/file_tile.dart';

/// Operations the installed engines do not currently advertise.
Set<OperationType> unavailableOperations(
  EngineProvider engines,
  List<OperationType> operations,
) {
  return {
    for (final operation in operations)
      if (engines.enginesForOperation(operation).isEmpty) operation,
  };
}

String newJobId() => 'job_${DateTime.now().microsecondsSinceEpoch}';

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(duration: const Duration(seconds: 5), content: Text(message)),
  );
}

void showJobSnack(BuildContext context, ProcessingResult? result) {
  if (result == null) {
    showMessage(context, 'Cancelled');
    return;
  }
  if (result.success) {
    if (result.outputs.isEmpty) {
      showMessage(context, 'Finished');
      return;
    }
    final file = result.outputs.first.file;
    final extra =
        result.outputs.length > 1
            ? ' and ${result.outputs.length - 1} more'
            : '';
    showMessage(
      context,
      'Saved ${file.displayName}$extra\n${friendlyPath(p.dirname(file.uri))}',
    );
    return;
  }
  showMessage(context, result.errorMessage ?? 'Processing failed');
}

/// Refresh the on-disk gallery after a successful job and tell the studio.
Future<void> revealSavedWork(
  BuildContext context,
  ProcessingResult? result,
  VoidCallback onSaved,
) async {
  if (result?.success == true) {
    await context.read<OutputLibrary>().refresh();
    onSaved();
  }
  if (!context.mounted) return;
  showJobSnack(context, result);
}

Widget galleryToggle({required bool showing, required VoidCallback onPressed}) {
  return IconButton(
    tooltip: showing ? 'Workspace' : 'Gallery',
    onPressed: onPressed,
    icon: Icon(showing ? Icons.dashboard_customize_outlined : Icons.grid_view),
  );
}

/// The card that holds an operation's fields and the process button.
class OperationFormCard extends StatelessWidget {
  const OperationFormCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class ProcessButton extends StatelessWidget {
  const ProcessButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton.icon(
        onPressed: busy ? null : onPressed,
        icon:
            busy
                ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                : const Icon(Icons.play_arrow),
        label: Text(label),
      ),
    );
  }
}

/// Selected files, optionally reorderable.
class SelectedFileList extends StatelessWidget {
  const SelectedFileList({
    super.key,
    required this.files,
    this.onRemove,
    this.onReorder,
    this.detail,
    this.maxHeight = 220,
  });

  final List<FileReference> files;
  final ValueChanged<FileReference>? onRemove;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final String? Function(FileReference file)? detail;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();
    final height = (files.length * 68.0).clamp(68.0, maxHeight);
    return SizedBox(
      height: height,
      child:
          onReorder == null
              ? ListView.builder(
                itemCount: files.length,
                itemBuilder: (context, index) => _tile(files[index], index),
              )
              : ReorderableListView.builder(
                itemCount: files.length,
                onReorder: onReorder!,
                buildDefaultDragHandles: false,
                itemBuilder: (context, index) => _tile(files[index], index),
              ),
    );
  }

  Widget _tile(FileReference file, int index) {
    return FileTile(
      key: ValueKey(file.uri),
      file: file,
      subtitleText: detail?.call(file),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onReorder != null)
            ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle),
            ),
          if (onRemove != null)
            IconButton(
              tooltip: 'Remove',
              onPressed: () => onRemove!(file),
              icon: const Icon(Icons.close, size: 18),
            ),
        ],
      ),
    );
  }
}

void reorderItems<T>(List<T> items, int oldIndex, int newIndex) {
  var target = newIndex;
  if (oldIndex < target) target -= 1;
  final item = items.removeAt(oldIndex);
  items.insert(target, item);
}

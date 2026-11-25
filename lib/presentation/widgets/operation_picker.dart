import 'package:flutter/material.dart';
import 'package:fileforge/core/theme/app_theme.dart';
import 'package:fileforge/domain/enums/enums.dart';

/// A selectable chip for an [OperationType].
///
/// Used in the operation picker grid within each studio.
class OperationChip extends StatelessWidget {
  final OperationType operation;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final bool enabled;

  const OperationChip({
    super.key,
    required this.operation,
    this.selected = false,
    this.onSelected,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(operation.displayName),
      selected: selected,
      onSelected: enabled ? onSelected : null,
      showCheckmark: false,
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: selected ? AppTheme.primaryColor : AppTheme.textSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        fontSize: 13,
      ),
      side: BorderSide(
        color: selected ? AppTheme.primaryColor : AppTheme.borderColor,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }
}

/// A horizontally-wrapping grid of [OperationChip]s for selecting an operation.
class OperationPicker extends StatelessWidget {
  /// All operations to display.
  final List<OperationType> operations;

  /// Currently selected operation, if any.
  final OperationType? selected;

  /// Called when an operation is selected.
  final ValueChanged<OperationType>? onSelected;

  /// Operations that should appear disabled (e.g. missing engine).
  final Set<OperationType> disabledOperations;

  const OperationPicker({
    super.key,
    required this.operations,
    this.selected,
    this.onSelected,
    this.disabledOperations = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children:
            operations.map((op) {
              final enabled = !disabledOperations.contains(op);
              return OperationChip(
                operation: op,
                selected: op == selected,
                enabled: enabled,
                onSelected: enabled ? (_) => onSelected?.call(op) : null,
              );
            }).toList(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../errors/error_mapper.dart';
import '../theme/app_colors.dart';
import 'fields.dart';
import 'responsive.dart';

abstract final class AppDialog {
  /// Shows [child] as a dialog on wide screens and a bottom sheet on phones.
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget child,
    double maxWidth = 520,
  }) {
    if (context.isMobile) {
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      );
    }
    return showDialog<T>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: MediaQuery.sizeOf(ctx).height * 0.9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: Theme.of(ctx).textTheme.titleLarge)),
                    IconButton(
                      tooltip: 'إغلاق',
                      icon: const Icon(Symbols.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'تأكيد',
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Asks for a cancellation reason. Returns null when dismissed.
  static Future<String?> cancelReason(BuildContext context, {required String title, required String message}) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(message),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'سبب الإلغاء',
                  controller: controller,
                  maxLines: 2,
                  validator: (v) => (v == null || v.trim().length < 3) ? 'اكتب سبب الإلغاء.' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, controller.text.trim());
            },
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
  }
}

abstract final class Toast {
  static void success(BuildContext context, String message) =>
      _show(context, message, Symbols.check_circle, AppColors.success);

  static void error(BuildContext context, Object error, [StackTrace? stack]) =>
      _show(context, ErrorMapper.message(error, stack), Symbols.error, AppColors.danger);

  static void info(BuildContext context, String message) =>
      _show(context, message, Symbols.info, AppColors.info);

  static void _show(BuildContext context, String message, IconData icon, Color color) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        width: context.isMobile ? null : 460,
        content: Row(
          children: [
            Icon(icon, color: color, size: 20, fill: 1),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ));
  }
}

/// Runs an async action and shows success/error feedback. Returns the result
/// or null on failure.
Future<T?> runWithFeedback<T>(
  BuildContext context,
  Future<T> Function() action, {
  String? success,
}) async {
  try {
    final result = await action();
    if (context.mounted && success != null) Toast.success(context, success);
    return result;
  } catch (e, s) {
    if (context.mounted) Toast.error(context, e, s);
    return null;
  }
}

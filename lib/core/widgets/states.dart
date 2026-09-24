import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../errors/error_mapper.dart';
import '../theme/app_colors.dart';
import 'buttons.dart';

/// Empty page: icon, Arabic explanation and a primary action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 52 : 72,
                height: compact ? 52 : 72,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: compact ? 26 : 34, color: AppColors.primary),
              ),
              SizedBox(height: compact ? 10 : 16),
              Text(title, style: t.titleMedium, textAlign: TextAlign.center),
              if (message != null) ...[
                const SizedBox(height: 6),
                Text(message!, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 18),
                PrimaryButton(label: actionLabel!, icon: Symbols.add, onPressed: onAction),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.stackTrace, this.onRetry});

  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.error, size: 44, color: AppColors.danger),
              const SizedBox(height: 12),
              Text('تعذر تحميل البيانات', style: t.titleMedium),
              const SizedBox(height: 6),
              Text(ErrorMapper.message(error, stackTrace),
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                SecondaryButton(label: 'إعادة المحاولة', icon: Symbols.refresh, onPressed: onRetry),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton placeholder rows shown while lists load.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.rows = 6, this.card = true});

  final int rows;
  final bool card;

  @override
  Widget build(BuildContext context) {
    final list = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const SkeletonBox(width: 38, height: 38, radius: 19),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 120.0 + (i % 3) * 40, height: 12),
                      const SizedBox(height: 8),
                      const SkeletonBox(width: 80, height: 10),
                    ],
                  ),
                ),
                const SkeletonBox(width: 70, height: 14),
              ],
            ),
          ),
      ],
    );
    return card ? Card(child: list) : list;
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, required this.width, required this.height, this.radius = 6});

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.neutralSoft,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Renders an [AsyncValue] with consistent loading / error / data states.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget? loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnReload: true,
      data: data,
      loading: () => loading ?? const LoadingState(),
      error: (e, s) => ErrorState(error: e, stackTrace: s, onRetry: onRetry),
    );
  }
}

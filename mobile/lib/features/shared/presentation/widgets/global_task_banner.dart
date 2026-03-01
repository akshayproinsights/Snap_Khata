import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/shared/presentation/providers/background_task_provider.dart';

class GlobalTaskBanner extends ConsumerWidget {
  const GlobalTaskBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskState = ref.watch(backgroundTaskProvider);

    if (!taskState.isProcessing) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: AppTheme.primary.withOpacity(0.1),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 8,
        left: 16,
        right: 16,
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              taskState.message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (taskState.actionLabel != null && taskState.onAction != null)
            TextButton(
              onPressed: taskState.onAction,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                taskState.actionLabel!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: AppTheme.primary),
            onPressed: () {
              ref.read(backgroundTaskProvider.notifier).clearTask();
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}

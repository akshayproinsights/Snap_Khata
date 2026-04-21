import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/upload/presentation/providers/upload_provider.dart';
import 'package:mobile/features/shared/presentation/providers/background_task_provider.dart';

class GlobalTaskBanner extends ConsumerWidget {
  const GlobalTaskBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskState = ref.watch(backgroundTaskProvider);
    final uploadState = ref.watch(uploadProvider);

    final isUploading = uploadState.isUploading;
    final isProcessing = uploadState.isProcessing;

    // ── Upload phase: urgent amber banner, not dismissible ──
    if (isUploading) {
      return _UrgentUploadBanner(context: context, ref: ref);
    }

    // ── Processing phase: calm blue banner, tappable to go to upload ──
    if (isProcessing) {
      return _ProcessingBanner(
          context: context, ref: ref, uploadState: uploadState);
    }

    // ── Background task (legacy / other tasks) ──
    if (!taskState.isProcessing) {
      return const SizedBox.shrink();
    }

    return _LegacyTaskBanner(taskState: taskState, ref: ref);
  }
}

/// Urgent amber banner shown during file upload.
/// NOT dismissible — user must stay on upload.
class _UrgentUploadBanner extends StatelessWidget {
  final BuildContext context;
  final WidgetRef ref;
  const _UrgentUploadBanner({required this.context, required this.ref});

  @override
  Widget build(BuildContext _) {
    final uploadState = ref.watch(uploadProvider);
    final pct = (uploadState.uploadProgress * 100).toInt();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          color: Colors.amber.shade700,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 6,
            bottom: 8,
            left: 16,
            right: 16,
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '📤 Uploading your order — Do not leave!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$pct% sent — Keep the app open',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Thin progress bar
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: uploadState.uploadProgress),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          builder: (_, v, __) => LinearProgressIndicator(
            value: v,
            minHeight: 3,
            backgroundColor: Colors.amber.shade900,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ],
    );
  }
}

/// Calming blue banner during server-side processing.
/// Tappable to return to upload tab.
class _ProcessingBanner extends StatelessWidget {
  final BuildContext context;
  final WidgetRef ref;
  final UploadState uploadState;
  const _ProcessingBanner({
    required this.context,
    required this.ref,
    required this.uploadState,
  });

  @override
  Widget build(BuildContext _) {
    final status = uploadState.processingStatus;
    final processed = status?.processed ?? 0;
    final total = status?.total ?? 1;
    final progress = total > 0 ? processed / total : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          color: const Color(0xFF1A3A6B),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 6,
            bottom: 8,
            left: 16,
            right: 8,
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '🧾 Reading your order in background',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'You can use other tabs — we\'ll notify you when done',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Tap to go back to upload
              TextButton(
                onPressed: () {
                  if (context.mounted) GoRouter.of(context).go('/upload');
                },
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'View',
                  style: TextStyle(
                    color: Colors.lightBlueAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Thin progress bar
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          builder: (_, v, __) => LinearProgressIndicator(
            value: v > 0 ? v : null, // indeterminate when no data yet
            minHeight: 3,
            backgroundColor: const Color(0xFF0D2247),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4D9FFF)),
          ),
        ),
      ],
    );
  }
}

/// Legacy task banner for non-upload background tasks.
class _LegacyTaskBanner extends StatelessWidget {
  final BackgroundTaskState taskState;
  final WidgetRef ref;
  const _LegacyTaskBanner({required this.taskState, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0066FF).withValues(alpha: 0.1),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 8,
        left: 16,
        right: 16,
      ),
      child: Row(
        children: [
          if (taskState.actionLabel != null)
            const Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: Color(0xFF00AA44),
            )
          else
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0066FF)),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              taskState.message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0066FF),
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
                  color: Color(0xFF0066FF),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Color(0xFF0066FF)),
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

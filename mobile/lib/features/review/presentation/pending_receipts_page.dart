import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/review/domain/models/review_models.dart';
import 'package:mobile/features/review/presentation/providers/review_provider.dart';
import 'package:mobile/shared/widgets/app_toast.dart';
import 'package:mobile/features/upload/presentation/providers/upload_provider.dart';
import 'package:mobile/features/shared/presentation/widgets/upload_results_summary.dart';
import 'package:mobile/features/shared/presentation/providers/background_task_provider.dart';

class PendingReceiptsPage extends ConsumerStatefulWidget {
  final int skippedCount;
  final bool autoLaunchReview;

  const PendingReceiptsPage({
    super.key,
    this.skippedCount = 0,
    this.autoLaunchReview = false,
  });

  @override
  ConsumerState<PendingReceiptsPage> createState() =>
      _PendingReceiptsPageState();
}

class _PendingReceiptsPageState extends ConsumerState<PendingReceiptsPage> {
  bool _autoLaunched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(reviewProvider.notifier).fetchReviewData();
        // Clear the "Orders ready to review!" banner — user has arrived at the review page
        ref.read(backgroundTaskProvider.notifier).clearTask();
      }
    });
  }



  Future<void> _syncAndFinish({required bool allDone}) async {
    // If not all receipts are reviewed, show a warning before proceeding
    if (!allDone) {
      final state = ref.read(reviewProvider);
      final pendingGroups =
          state.groups.where((g) => g.status == 'Pending').toList();
      final pendingCount = pendingGroups.length;
      final errorCount = state.groups.where((g) => g.status == 'Error').length;

      final lines = <String>[];
      if (pendingCount > 0) {
        lines.add(
            '$pendingCount receipt${pendingCount > 1 ? 's' : ''} not reviewed yet');
      }
      if (errorCount > 0) {
        lines.add(
            '$errorCount receipt${errorCount > 1 ? 's have' : ' has'} errors');
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(LucideIcons.alertTriangle, color: context.warningColor, size: 22),
              const SizedBox(width: 10),
              const Text('Not all receipts reviewed',
                  style: TextStyle(fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ',
                          style: TextStyle(
                              color: context.warningColor,
                              fontWeight: FontWeight.bold)),
                      Expanded(
                          child: Text(line,
                              style: const TextStyle(
                                  fontSize: 14, height: 1.4))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Unreviewed receipts will still be synced but may have incorrect data.',
                style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondaryColor,
                    height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Review First'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: context.warningColor),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sync Anyway'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;
    }

    await ref.read(reviewProvider.notifier).syncAndFinish();
    if (!mounted) return;
    final state = ref.read(reviewProvider);
    if (state.error == null) {
      AppToast.showSuccess(context, 'Receipts synced successfully!',
          title: 'Sync Complete');
      context.go('/');
    } else {
      AppToast.showError(context, state.error!, title: 'Sync Failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ReviewState>(reviewProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        AppToast.showError(context, next.error!, title: 'Update Failed');
      }
    });
    final state = ref.watch(reviewProvider);
    final uploadState = ref.watch(uploadProvider);
    final groups = state.groups;

    if (widget.autoLaunchReview && !_autoLaunched && !state.isLoading && groups.isNotEmpty) {
      _autoLaunched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.push('/receipt-review', extra: {
            'group': groups.first,
            'allGroups': groups,
            'currentIndex': 0,
          });
        }
      });
    }

    final allDone = groups.isNotEmpty && groups.every((g) => g.isComplete);
    final pendingCount = groups.where((g) => g.status == 'Pending').length;
    final doneCount = groups.where((g) => g.status == 'Done').length;
    final errorCount = groups.where((g) => g.status == 'Error').length;

    final completedStatus = uploadState.lastCompletedStatus;
    final showSummaryOverlay = completedStatus != null;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => context.go('/'),
        ),
        title: const Text('PENDING REVIEW',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            )),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          // ── Main list body ───────────────────────────────────────
          state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Old skippedCount fallback banner (when lastCompletedStatus unavailable)
                    if (!showSummaryOverlay && widget.skippedCount > 0)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(
                            left: 16, right: 16, top: 16),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: context.warningColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: context.warningColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('⏭️',
                                style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'We skipped ${widget.skippedCount} image${widget.skippedCount > 1 ? 's' : ''} since they were already uploaded.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: context.warningColor,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
                    _buildProgressHeader(
                        groups.length, doneCount, pendingCount, errorCount),
                    if (state.isSyncing)
                      LinearProgressIndicator(
                          value: state.syncProgress?.percentage != null
                              ? state.syncProgress!.percentage / 100
                              : null),
                    Expanded(
                      child: groups.isEmpty
                          ? const Center(child: Text('All caught up! 🎉'))
                          : ListView.separated(
                              padding: const EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  top: 16,
                                  bottom: 100),
                              itemCount: groups.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                return _buildReceiptCard(groups[index], groups)
                                    .animate()
                                    .fadeIn(
                                        duration: 300.ms,
                                        delay: (50 * index).ms)
                                    .slideY(
                                        begin: 0.1,
                                        curve: Curves.easeOut);
                              },
                            ),
                    )
                  ],
                ),

          // ── Results summary overlay ──────────────────────────────
          if (showSummaryOverlay)
            UploadResultsSummary(
              status: completedStatus,
              ctaLabel: 'Review Orders →',
              onDismiss: () {
                ref.read(uploadProvider.notifier).clearCompletedStatus();
              },
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: (!showSummaryOverlay && groups.isNotEmpty)
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: FloatingActionButton.extended(
                  onPressed: state.isSyncing
                      ? null
                      : () => _syncAndFinish(allDone: allDone),
                  backgroundColor: context.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  icon: state.isSyncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(LucideIcons.checkCheck),
                  label: Text(
                    state.isSyncing
                        ? 'Syncing... ${state.syncProgress?.percentage ?? 0}%'
                        : (allDone ? 'Sync & Finish' : 'Sync Anyway'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildProgressHeader(int total, int done, int pending, int error) {
    if (total == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      color: context.surfaceColor,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Review Progress',
                  style:
                      TextStyle(color: context.textSecondaryColor, fontSize: 13)),
              Text('$done of $total Done',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? done / total : 0,
              backgroundColor: context.borderColor.withValues(alpha: 0.2),
              color: context.successColor,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (pending > 0)
                _buildBadge(
                    LucideIcons.clock, '$pending Pending', context.warningColor),
              if (error > 0)
                _buildBadge(
                    LucideIcons.alertCircle, '$error Errors', context.errorColor),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildReceiptCard(InvoiceReviewGroup group, List<InvoiceReviewGroup> allGroups) {
    final header = group.header;
    final status = group.status;
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'Done':
        statusColor = context.successColor;
        statusIcon = LucideIcons.checkCircle;
        break;
      case 'Error':
        statusColor = context.errorColor;
        statusIcon = LucideIcons.alertTriangle;
        break;
      default:
        statusColor = context.warningColor;
        statusIcon = LucideIcons.clock;
    }

    return InkWell(
      onTap: () {
        context.push('/receipt-review', extra: {
          'group': group,
          'allGroups': allGroups,
          'currentIndex': allGroups.indexOf(group),
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: status == 'Error' ? context.errorColor.withValues(alpha: 0.3) : context.borderColor),
          boxShadow: context.premiumShadow,
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: context.isDark ? context.surfaceColor : context.borderColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: (header?.receiptLink.isNotEmpty == true)
                  ? CachedNetworkImage(
                      imageUrl: header!.receiptLink,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          Icon(LucideIcons.imageOff, color: context.textSecondaryColor),
                    )
                  : Icon(LucideIcons.fileText, color: context.textSecondaryColor),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    header?.receiptNumber.isNotEmpty == true
                        ? 'Receipt #${header!.receiptNumber}'
                        : 'Unknown Receipt',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(LucideIcons.calendar,
                          size: 12, color: context.textSecondaryColor),
                      const SizedBox(width: 4),
                      Text(
                        header?.date.isNotEmpty == true
                            ? header!.date
                            : 'No Date',
                        style: TextStyle(
                            fontSize: 12, color: context.textSecondaryColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${group.lineItems.length} items',
                    style: TextStyle(
                        fontSize: 12, color: context.textSecondaryColor),
                  ),
                ],
              ),
            ),
            // Status Indicator + Sync & Share
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // Status badge
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 3),
                    Text(status,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 4),
            // Chevron
            Icon(LucideIcons.chevronRight,
                color: context.textSecondaryColor, size: 20),
          ],
        ),
      ),
    );
  }
}

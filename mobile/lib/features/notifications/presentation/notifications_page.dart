import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/notifications/domain/models/notification_models.dart';
import 'package:mobile/features/notifications/presentation/providers/notification_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationProvider);
    final items = state.items;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          if (items.isNotEmpty) ...[
            if (state.unreadCount > 0)
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref.read(notificationProvider.notifier).markAllRead();
                },
                child: const Text('Mark all read',
                    style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
            IconButton(
              icon: const Icon(LucideIcons.trash2,
                  size: 18, color: AppTheme.textSecondary),
              tooltip: 'Clear all',
              onPressed: () => _confirmClear(context, ref),
            ),
          ],
        ],
      ),
      body:
          items.isEmpty ? _buildEmptyState() : _buildList(context, ref, items),
    );
  }

  // ── Empty ─────────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.bellOff,
                size: 52, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          const Text('No Notifications',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text('You\'re all caught up!',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        ],
      )
          .animate()
          .fadeIn(duration: 400.ms)
          .slideY(begin: 0.08, duration: 400.ms, curve: Curves.easeOut),
    );
  }

  // ── Grouped List ──────────────────────────────────────────────────────────

  Widget _buildList(
      BuildContext context, WidgetRef ref, List<NotificationItem> items) {
    // Group by date label: Today, Yesterday, older dates
    final groups = <String, List<NotificationItem>>{};
    final now = DateTime.now();

    for (final item in items) {
      final dayDiff = DateTime(now.year, now.month, now.day)
          .difference(DateTime(
              item.timestamp.year, item.timestamp.month, item.timestamp.day))
          .inDays;

      String label;
      if (dayDiff == 0) {
        label = 'Today';
      } else if (dayDiff == 1) {
        label = 'Yesterday';
      } else {
        label = DateFormat('d MMMM yyyy').format(item.timestamp);
      }
      groups.putIfAbsent(label, () => []).add(item);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        for (final entry in groups.entries) ...[
          // Section header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(entry.key,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.5)),
          ),
          ...entry.value.asMap().entries.map((e) {
            return _NotificationCard(
              item: e.value,
              index: e.key,
              onTap: () => _handleTap(context, ref, e.value),
              onDismiss: () =>
                  ref.read(notificationProvider.notifier).dismiss(e.value.id),
            );
          }),
        ],
      ],
    );
  }

  void _handleTap(BuildContext context, WidgetRef ref, NotificationItem item) {
    HapticFeedback.lightImpact();
    // Mark as read
    if (!item.isRead) {
      ref.read(notificationProvider.notifier).markRead(item.id);
    }
    // Navigate to the relevant page
    try {
      context.goNamed(item.routeName);
    } catch (_) {
      context.go('/');
    }
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('This will permanently remove all notifications.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(notificationProvider.notifier).clearAll();
    }
  }
}

// ── Notification Card ─────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  final NotificationItem item;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.item,
    required this.index,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor(item.type);
    final typeIcon = _typeIcon(item.type);
    final timeStr = DateFormat('h:mm a').format(item.timestamp);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(LucideIcons.trash2, color: AppTheme.error),
      ),
      confirmDismiss: (_) async => true,
      onDismissed: (_) => onDismiss(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: item.isRead
                ? AppTheme.surface
                : AppTheme.primary.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  item.isRead ? AppTheme.border : typeColor.withOpacity(0.25),
              width: item.isRead ? 1 : 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon badge
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon, color: typeColor, size: 20),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Type badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(item.typeLabel,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: typeColor)),
                        ),
                        const Spacer(),
                        Text(timeStr,
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.textSecondary)),
                        if (!item.isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(item.title,
                        style: TextStyle(
                            fontWeight:
                                item.isRead ? FontWeight.w500 : FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text(item.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      )
          .animate(delay: (index * 40).ms)
          .fadeIn(duration: 250.ms)
          .slideX(begin: 0.05, curve: Curves.easeOut),
    );
  }

  Color _typeColor(NotificationType t) {
    switch (t) {
      case NotificationType.invoiceReady:
        return const Color(0xFF22C55E); // green
      case NotificationType.lowStock:
        return AppTheme.warning;
      case NotificationType.poCreated:
        return AppTheme.primary;
      case NotificationType.syncComplete:
        return const Color(0xFF06B6D4); // cyan
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _typeIcon(NotificationType t) {
    switch (t) {
      case NotificationType.invoiceReady:
        return LucideIcons.fileCheck;
      case NotificationType.lowStock:
        return LucideIcons.alertTriangle;
      case NotificationType.poCreated:
        return LucideIcons.shoppingCart;
      case NotificationType.syncComplete:
        return LucideIcons.refreshCw;
      default:
        return LucideIcons.bell;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:mobile/features/upload/domain/models/upload_models.dart';

/// Full-screen results card shown after every upload completes.
///
/// Displays:
///   ✅ X invoice(s) added
///   ⏭️ X duplicate(s) skipped  (expandable list)
///   ❌ X failed                 (with retry advice)
///
/// [onDismiss] is called when the user taps "Review →" or after
/// [autoDismissAfter] seconds (default 8s), whichever comes first.
class UploadResultsSummary extends StatefulWidget {
  final UploadTaskStatus status;

  /// Label for the primary CTA button, e.g. "Review Inventory" or "Review Orders".
  final String ctaLabel;

  final VoidCallback onDismiss;

  /// Auto-dismiss delay. Set to null to disable auto-dismiss.
  final Duration autoDismissAfter;

  const UploadResultsSummary({
    super.key,
    required this.status,
    required this.ctaLabel,
    required this.onDismiss,
    this.autoDismissAfter = const Duration(seconds: 8),
  });

  @override
  State<UploadResultsSummary> createState() => _UploadResultsSummaryState();
}

class _UploadResultsSummaryState extends State<UploadResultsSummary>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  bool _skippedExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();

    // Auto-dismiss after delay
    Future.delayed(widget.autoDismissAfter, () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final added = status.processed;
    final skipped = status.skipped;
    final failed = status.failed;
    final skippedDetails = status.skippedDetails;
    final errors = status.errors;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FadeTransition(
      opacity: _fadeIn,
      child: Container(
        color: colorScheme.surface.withValues(alpha: 0.96),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Header ──────────────────────────────────────────────
              const SizedBox(height: 8),
              Text(
                'Upload Complete',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Here\'s a breakdown of what happened',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),

              // ── Result rows ─────────────────────────────────────────
              _ResultRow(
                icon: Icons.check_circle_rounded,
                iconColor: Colors.green.shade600,
                label:
                    '$added invoice${added == 1 ? '' : 's'} added successfully',
                visible: added >= 0,
              ),
              if (skipped > 0) ...[
                const SizedBox(height: 10),
                _SkippedRow(
                  count: skipped,
                  details: skippedDetails,
                  expanded: _skippedExpanded,
                  onToggle: () =>
                      setState(() => _skippedExpanded = !_skippedExpanded),
                ),
              ],
              if (failed > 0) ...[
                const SizedBox(height: 10),
                _ResultRow(
                  icon: Icons.error_rounded,
                  iconColor: colorScheme.error,
                  label:
                      '$failed file${failed == 1 ? '' : 's'} could not be processed',
                  subtitle: 'Retake the photo more clearly and upload again',
                  visible: true,
                ),
                if (errors.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _ErrorList(errors: errors),
                ],
              ],

              const SizedBox(height: 32),

              // ── CTA ─────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.onDismiss,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  label: Text(widget.ctaLabel),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Supporting widgets ────────────────────────────────────────────────────

class _ResultRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final bool visible;

  const _ResultRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.subtitle,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkippedRow extends StatelessWidget {
  final int count;
  final List<Map<String, dynamic>> details;
  final bool expanded;
  final VoidCallback onToggle;

  const _SkippedRow({
    required this.count,
    required this.details,
    required this.expanded,
    required this.onToggle,
  });

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final d = DateTime.parse(raw);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amber = Colors.amber.shade700;

    return Container(
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          // Header tap target
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.skip_next_rounded, color: amber, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$count duplicate${count == 1 ? '' : 's'} skipped — already uploaded',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (details.isNotEmpty)
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: amber,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
          // Expandable list
          if (expanded && details.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: details.map((dup) {
                  // Support both inventory (invoice_number) and sales (receipt_number)
                  final id = (dup['invoice_number'] as String?)?.isNotEmpty == true
                      ? dup['invoice_number']
                      : dup['receipt_number'];
                  final date = _formatDate(
                    dup['invoice_date'] as String? ??
                        dup['invoice_date'] as String?,
                  );
                  final label = [
                    if (id != null && id.toString().isNotEmpty) 'Invoice #$id',
                    if (date.isNotEmpty) date,
                  ].join(' · ');

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 6, color: amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            label.isNotEmpty ? label : 'Already uploaded',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorList extends StatelessWidget {
  final List<String> errors;
  const _ErrorList({required this.errors});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: errors.take(3).map((e) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Text(
            '• $e',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/context_extension.dart';
import 'package:mobile/core/utils/currency_formatter.dart';
import 'package:mobile/features/udhar/domain/models/unified_party.dart';
import 'package:intl/intl.dart';

class PartyActivityCard extends StatelessWidget {
  final UnifiedParty party;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isSelectionMode;

  const PartyActivityCard({
    super.key,
    required this.party,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isSelectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDue = party.balance.abs() > 0.01;
    // For customers, positive balance is receivable (To Collect).
    // For suppliers, negative balance is payable (To Give).
    // In UnifiedParty: Customer balance is positive, Supplier balance is negative.
    final bool isPayable = party.balance < 0; 
    
    final Color statusColor = isDue 
        ? (isPayable ? context.errorColor : context.successColor)
        : context.textSecondaryColor.withValues(alpha: 0.5);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: context.premiumShadow,
        border: Border.all(color: context.borderColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            children: [
              // Selection background
              if (isSelected)
                Positioned.fill(
                  child: Container(
                    color: context.primaryColor.withValues(alpha: 0.05),
                  ),
                ),
              // Status Bar
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  color: statusColor,
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Type Badge & Timestamp
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (isSelectionMode) ...[
                              Icon(
                                isSelected ? LucideIcons.checkCircle2 : LucideIcons.circle,
                                color: isSelected ? context.primaryColor : context.textSecondaryColor.withValues(alpha: 0.3),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                            ],
                            _buildTypeBadge(context),
                            if (party.latestUploadDate != null || party.lastTransactionDate != null) ...[
                              const SizedBox(width: 8),
                              _buildTimestamp(context, party.latestUploadDate ?? party.lastTransactionDate!),
                            ],
                          ],
                        ),
                        _buildStatusBadge(context, isDue, isPayable),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Middle Row: Avatar, Name & Balance
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildAvatar(context, isDue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                party.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: context.textColor,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                isPayable ? 'YOU GIVE' : 'YOU GET',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: context.textSecondaryColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.format(party.balance.abs()),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: statusColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'BALANCE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: context.textSecondaryColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Bottom Row: Bill Details
                    if (party.latestBillNumber != null || party.latestBillAmount != null)
                      Container(
                        padding: const EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: context.borderColor.withValues(alpha: 0.5), width: 1),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (party.latestBillNumber != null) ...[
                              Icon(LucideIcons.fileText, size: 14, color: context.textSecondaryColor.withValues(alpha: 0.5)),
                              const SizedBox(width: 4),
                              Text(
                                '#${party.latestBillNumber}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: context.textSecondaryColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            if (party.latestBillAmount != null) ...[
                              Text(
                                'BILL TOTAL:',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: context.textSecondaryColor.withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                CurrencyFormatter.format(party.latestBillAmount!),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: context.textSecondaryColor,
                                ),
                              ),
                            ],
                            const Spacer(),
                            Icon(LucideIcons.chevronRight, size: 16, color: context.textSecondaryColor.withValues(alpha: 0.3)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(BuildContext context) {
    final isCustomer = party.type == PartyType.customer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (isCustomer ? Colors.blue : Colors.orange).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isCustomer ? 'CUSTOMER' : 'SUPPLIER',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: isCustomer ? Colors.blue : Colors.orange,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTimestamp(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final isYesterday = date.year == now.year && date.month == now.month && date.day == now.day - 1;
    
    String dayPart = DateFormat('MMM dd').format(date);
    if (isToday) dayPart = 'Today';
    if (isYesterday) dayPart = 'Yesterday';
    
    final timePart = DateFormat('h:mm a').format(date);

    return Text(
      '$dayPart • $timePart',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: context.textSecondaryColor.withValues(alpha: 0.6),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, bool isDue, bool isPayable) {
    if (!isDue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: context.successColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'SETTLED',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: context.successColor,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (isPayable ? context.errorColor : context.successColor).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'DUE',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: isPayable ? context.errorColor : context.successColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, bool isDue) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isDue ? context.textColor : context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor, width: 1),
      ),
      child: Center(
        child: Text(
          party.name.isNotEmpty ? party.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: isDue ? context.backgroundColor : context.textSecondaryColor,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

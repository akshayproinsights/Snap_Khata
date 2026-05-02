import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile/core/theme/context_extension.dart';
import 'package:mobile/features/udhar/domain/models/unified_party.dart';
import 'package:mobile/features/udhar/presentation/widgets/party_activity_card.dart';
import 'package:mobile/features/udhar/presentation/widgets/add_party_entry_sheet.dart';
import 'package:flutter/services.dart';

class SwipeablePartyCard extends StatelessWidget {
  final UnifiedParty party;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isSelectionMode;

  const SwipeablePartyCard({
    super.key,
    required this.party,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isSelectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isSelectionMode) {
      return PartyActivityCard(
        party: party,
        onTap: onTap,
        onLongPress: onLongPress,
        isSelected: isSelected,
        isSelectionMode: isSelectionMode,
      );
    }

    return Slidable(
      key: ValueKey(party.uniqueId),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (context) {
              HapticFeedback.mediumImpact();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const AddPartyEntrySheet(),
              );
            },
            backgroundColor: context.primaryColor,
            foregroundColor: Colors.white,
            icon: LucideIcons.plus,
            label: 'Entry',
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (context) {
              HapticFeedback.lightImpact();
              // WhatsApp reminder logic
              // Since we don't have phone number in UnifiedParty yet, 
              // we might need to fetch it or use a default reminder flow.
            },
            backgroundColor: context.successColor,
            foregroundColor: Colors.white,
            icon: LucideIcons.messageSquare,
            label: 'WhatsApp',
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
          ),
        ],
      ),
      child: PartyActivityCard(
        party: party,
        onTap: onTap,
        onLongPress: onLongPress,
        isSelected: isSelected,
        isSelectionMode: isSelectionMode,
      ),
    );
  }
}

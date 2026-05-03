import 'package:flutter/material.dart';
import 'package:mobile/features/udhar/domain/models/unified_party.dart';
import 'package:mobile/features/udhar/presentation/widgets/party_activity_card.dart';

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
    return PartyActivityCard(
      party: party,
      onTap: onTap,
      onLongPress: onLongPress,
      isSelected: isSelected,
      isSelectionMode: isSelectionMode,
    );
  }
}

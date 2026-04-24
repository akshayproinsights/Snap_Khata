import 'package:flutter/material.dart';

class DualActionFab extends StatelessWidget {
  const DualActionFab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          heroTag: 'fab_vendor_scan',
          onPressed: () {
            debugPrint("Vendor Scan Triggered");
          },
          icon: const Icon(Icons.camera_alt),
          label: const Text("Scan Purchase Bill"),
          backgroundColor: Colors.red.shade600,
          foregroundColor: Colors.white,
        ),
        const SizedBox(height: 16),
        FloatingActionButton.extended(
          heroTag: 'fab_customer_snap',
          onPressed: () {
            debugPrint("Customer Snap Triggered");
          },
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text("Snap New Order"),
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
        ),
      ],
    );
  }
}

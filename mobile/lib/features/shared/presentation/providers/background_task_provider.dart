import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BackgroundTaskState {
  final bool isProcessing;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  BackgroundTaskState({
    this.isProcessing = false,
    this.message = '',
    this.actionLabel,
    this.onAction,
  });

  BackgroundTaskState copyWith({
    bool? isProcessing,
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return BackgroundTaskState(
      isProcessing: isProcessing ?? this.isProcessing,
      message: message ?? this.message,
      actionLabel: actionLabel ?? this.actionLabel,
      onAction: onAction ?? this.onAction,
    );
  }
}

class BackgroundTaskNotifier extends StateNotifier<BackgroundTaskState> {
  BackgroundTaskNotifier() : super(BackgroundTaskState());

  void startTask(String message) {
    state = BackgroundTaskState(isProcessing: true, message: message);
  }

  void updateTask(String message) {
    if (state.isProcessing) {
      state = state.copyWith(message: message);
    }
  }

  void completeTask(String message,
      {String? actionLabel, VoidCallback? onAction}) {
    state = BackgroundTaskState(
      isProcessing: true,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );

    // Auto clear after 5 seconds if no action is provided
    if (actionLabel == null && onAction == null) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) clearTask();
      });
    }
  }

  void completeTaskWithAction(
      String message, String actionLabel, VoidCallback onAction) {
    state = BackgroundTaskState(
      isProcessing: true, // Keep it visible as a banner
      message: message,
      actionLabel: actionLabel,
      onAction: () {
        onAction();
        clearTask();
      },
    );
  }

  void clearTask() {
    state = BackgroundTaskState();
  }
}

final backgroundTaskProvider =
    StateNotifierProvider<BackgroundTaskNotifier, BackgroundTaskState>((ref) {
  return BackgroundTaskNotifier();
});

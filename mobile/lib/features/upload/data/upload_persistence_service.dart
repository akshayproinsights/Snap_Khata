import 'package:shared_preferences/shared_preferences.dart';

/// Persists the active upload task ID to disk so it can survive app kills.
/// Written when processing starts, cleared when processing ends (success/fail/duplicate).
class UploadPersistenceService {
  static const String _taskIdKey = 'upload_active_task_id';
  static const String _fileCountKey = 'upload_active_file_count';
  static const String _startedAtKey = 'upload_started_at_ms';

  // ── Max age: if a task is >15 minutes old we assume it's dead ──
  static const int _maxTaskAgeMs = 15 * 60 * 1000;

  /// Persist an active task to disk.
  static Future<void> saveTask(String taskId, {int fileCount = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_taskIdKey, taskId);
    await prefs.setInt(_fileCountKey, fileCount);
    await prefs.setInt(_startedAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Remove the persisted task (call on success, failure, or explicit cancel).
  static Future<void> clearTask() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_taskIdKey);
    await prefs.remove(_fileCountKey);
    await prefs.remove(_startedAtKey);
  }

  /// Returns the persisted task ID if one exists and is still within max age.
  /// Returns null if no task or if the task is stale (>15 min old).
  static Future<String?> loadActiveTaskId() async {
    final prefs = await SharedPreferences.getInstance();
    final taskId = prefs.getString(_taskIdKey);
    if (taskId == null || taskId.isEmpty) return null;

    // Stale-task guard
    final startedAt = prefs.getInt(_startedAtKey) ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - startedAt;
    if (age > _maxTaskAgeMs) {
      await clearTask(); // clean up stale entry
      return null;
    }

    return taskId;
  }

  /// Returns the file count saved with the active task (for UI messaging).
  static Future<int> loadActiveFileCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_fileCountKey) ?? 1;
  }

  /// Quick synchronous check at startup (after getInstance() is ready).
  static Future<bool> hasActiveTask() async {
    final id = await loadActiveTaskId();
    return id != null;
  }
}

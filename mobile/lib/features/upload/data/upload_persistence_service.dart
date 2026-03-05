import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the active upload task ID to disk so it can survive app kills.
/// Written when processing starts, cleared when processing ends (success/fail/duplicate).
///
/// Also persists the **upload-phase** (before a task ID exists) so we can
/// recover even when the user switches away during the R2 upload.
class UploadPersistenceService {
  static const String _taskIdKey = 'upload_active_task_id';
  static const String _fileCountKey = 'upload_active_file_count';
  static const String _startedAtKey = 'upload_started_at_ms';

  // ── Upload-phase keys (pre-task-id) ──
  static const String _uploadPhaseKey = 'upload_phase_active';
  static const String _uploadPhaseFilesKey = 'upload_phase_file_paths';
  static const String _uploadPhaseStartedKey = 'upload_phase_started_at_ms';

  // ── Max age: if a task is >15 minutes old we assume it's dead ──
  static const int _maxTaskAgeMs = 15 * 60 * 1000;

  // ─────────────── Processing-task persistence ───────────────

  /// Persist an active task to disk.
  static Future<void> saveTask(String taskId, {int fileCount = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_taskIdKey, taskId);
    await prefs.setInt(_fileCountKey, fileCount);
    await prefs.setInt(_startedAtKey, DateTime.now().millisecondsSinceEpoch);
    // Once we have a real task ID, the upload-phase marker is no longer needed
    await clearUploadPhase();
  }

  /// Remove the persisted task (call on success, failure, or explicit cancel).
  static Future<void> clearTask() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_taskIdKey);
    await prefs.remove(_fileCountKey);
    await prefs.remove(_startedAtKey);
    await clearUploadPhase(); // belt-and-suspenders
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

  // ─────────────── Upload-phase persistence (pre-task-id) ───────────────
  // Written BEFORE the R2 upload starts, so even if the user leaves during
  // the HTTP upload we know files are in-flight and can show the overlay.

  /// Persist that an upload is in-flight (before we get a task ID back).
  static Future<void> saveUploadPhase(List<String> filePaths) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_uploadPhaseKey, true);
    await prefs.setString(_uploadPhaseFilesKey, jsonEncode(filePaths));
    await prefs.setInt(
        _uploadPhaseStartedKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Clear the upload-phase marker.
  static Future<void> clearUploadPhase() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_uploadPhaseKey);
    await prefs.remove(_uploadPhaseFilesKey);
    await prefs.remove(_uploadPhaseStartedKey);
  }

  /// Returns true if the app was killed mid-upload (before task ID was obtained).
  static Future<bool> hasUploadPhase() async {
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getBool(_uploadPhaseKey) ?? false;
    if (!active) return false;

    // Stale guard — same 15-minute window
    final startedAt = prefs.getInt(_uploadPhaseStartedKey) ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - startedAt;
    if (age > _maxTaskAgeMs) {
      await clearUploadPhase();
      return false;
    }
    return true;
  }

  /// Returns persisted file paths from the upload-phase.
  static Future<List<String>> loadUploadPhaseFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_uploadPhaseFilesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return List<String>.from(jsonDecode(raw));
    } catch (_) {
      return [];
    }
  }

  // ─────────────── Composite check: anything active? ───────────────

  /// Returns true if EITHER a processing task OR an upload-phase is active.
  /// Use this for fast synchronous-ish UI guards.
  static Future<bool> hasAnyActiveWork() async {
    final hasTask = await hasActiveTask();
    if (hasTask) return true;
    return await hasUploadPhase();
  }
}

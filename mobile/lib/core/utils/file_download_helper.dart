import 'package:flutter/foundation.dart' show kIsWeb;
import 'file_download_helper_stub.dart'
    if (dart.library.js_interop) 'file_download_helper_web.dart' as impl;

class FileDownloadHelper {
  /// Triggers a direct file download in the browser on Flutter Web.
  /// No-op on native platforms.
  static void downloadFile(List<int> bytes, String fileName, String mimeType) {
    if (kIsWeb) {
      impl.downloadFileWeb(bytes, fileName, mimeType);
    }
  }
}

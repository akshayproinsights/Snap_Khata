import 'dart:convert';
import 'dart:js_interop';

@JS('eval')
external void _jsEval(String code);

/// Web implementation for downloading files in the browser.
/// Uses base64 conversion and JS eval to remain fully compatible with both
/// dart2js and dart2wasm compilation modes, bypassing dart:html.
void downloadFileWeb(List<int> bytes, String fileName, String mimeType) {
  final base64String = base64Encode(bytes);
  final jsCode = '''
    (function() {
      const base64 = "$base64String";
      const byteCharacters = atob(base64);
      const byteNumbers = new Array(byteCharacters.length);
      for (let i = 0; i < byteCharacters.length; i++) {
        byteNumbers[i] = byteCharacters.charCodeAt(i);
      }
      const byteArray = new Uint8Array(byteNumbers);
      const blob = new Blob([byteArray], {type: "$mimeType"});
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = "$fileName";
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
    })();
  ''';
  _jsEval(jsCode);
}

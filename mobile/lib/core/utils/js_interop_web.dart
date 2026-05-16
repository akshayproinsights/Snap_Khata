import 'dart:js_interop';

/// Calls JavaScript's eval() function directly.
/// Only available on web — gated by conditional import in the caller.
@JS('eval')
external String jsEval(String code);

/// Native stub — jsEval is never called on native because _canShareFiles()
/// returns true immediately when !kIsWeb, before this function is reached.
String jsEval(String code) => '';

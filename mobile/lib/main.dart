import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/routing/app_router.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/theme/theme_provider.dart';
import 'package:mobile/core/network/sync_queue_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mobile/core/localization/locale_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile/core/notifications/notification_service.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'syncDataTask') {
      try {
        WidgetsFlutterBinding.ensureInitialized();
        final appDocumentDir = await getApplicationDocumentsDirectory();
        await Hive.initFlutter(appDocumentDir.path);
        await Hive.openBox('sync_queue');

        final box = Hive.box('sync_queue');
        if (box.isNotEmpty) {
          debugPrint('Background sync started: ${box.length} pending items');
          await SyncQueueService().processQueue();
        }
        return Future.value(true);
      } catch (err) {
        debugPrint('Background sync failed: $err');
        return Future.value(false); // Retries based on workmanager backoff
      }
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize background tasks
  try {
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  } catch (e) {
    debugPrint('Workmanager init failed (non-fatal): $e');
  }

  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);

  // Initialize Firebase — wrapped so app still launches even if Firebase fails
  try {
    await Firebase.initializeApp();

    // Setup Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // Initialize notifications in the background — do NOT await, so FCM token
    // fetch never blocks the app from showing the login screen.
    NotificationService.initialize().catchError((e) {
      debugPrint('NotificationService init failed (non-fatal): $e');
    });
  } catch (e) {
    debugPrint('Firebase init failed (non-fatal): $e');
  }

  // Open cache boxes
  await Hive.openBox('dashboard_cache');
  await Hive.openBox('stock_cache');
  await Hive.openBox('sync_queue');
  await Hive.openBox('notifications');

  SyncQueueService().init();

  // Create a ProviderContainer so NotificationService can write to providers
  // outside the widget tree (e.g. from Firebase callbacks)
  final container = ProviderContainer();
  NotificationService.setContainer(container);

  runApp(
    const ProviderScope(
      overrides: [],
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'DigiEntry',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
      locale: currentLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}

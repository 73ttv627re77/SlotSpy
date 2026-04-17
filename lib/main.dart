import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:home_widget/home_widget.dart';

import 'theme/slotspy_dark_theme.dart';
import 'services/database_service.dart';
import 'services/backend_service.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';
import 'providers/watch_provider.dart';
import 'screens/home_screen.dart';
import 'widgets/alert_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final prefs = await SharedPreferences.getInstance();
  final db = DatabaseService();
  final backendUrl = prefs.getString('backend_url');
  final useCustomBackend = prefs.getBool('use_custom_backend') ?? false;
  final backend = (useCustomBackend && backendUrl != null && backendUrl.isNotEmpty)
      ? BackendService(backendUrl)
      : null;
  final notifications = NotificationService();

  await notifications.initialize();
  await notifications.requestPermissions();

  final push = PushService(notifications);
  push.setBackend(backend);
  await push.initialize();

  // Initialize home widget
  await _initHomeWidget();

  runApp(
    SlotSpyApp(
      prefs: prefs,
      db: db,
      notifications: notifications,
      backend: backend,
    ),
  );
}

Future<void> _initHomeWidget() async {
  try {
    await HomeWidget.setAppGroupId('group.com.slotspy.app');
  } catch (_) {}
}

class SlotSpyApp extends StatelessWidget {
  final SharedPreferences prefs;
  final DatabaseService db;
  final NotificationService notifications;
  final BackendService? backend;

  const SlotSpyApp({
    super.key,
    required this.prefs,
    required this.db,
    required this.notifications,
    this.backend,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => WatchProvider(db, notifications, backend),
        ),
        ChangeNotifierProvider(
          create: (_) => SlotProvider(db, backend),
        ),
        ChangeNotifierProxyProvider<WatchProvider, PollingService>(
          create: (_) => PollingService(db, notifications),
          update: (_, watchProvider, pollingService) {
            pollingService?.setProviders(
              Provider.of<SlotProvider>(_, listen: false),
              watchProvider,
            );
            return pollingService ?? PollingService(db, notifications);
          },
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          _updateWakelock(settings.keepAwakeEnabled);
          return MaterialApp(
            title: 'SlotSpy',
            debugShowCheckedModeBanner: false,
            theme: SlotSpyDarkTheme.theme,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: MediaQuery.of(context).textScaler,
                ),
                child: child ?? const SizedBox(),
              );
            },
            home: const MainNavigator(),
          );
        },
      ),
    );
  }

  void _updateWakelock(bool enabled) {
    if (enabled) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  SlotMatch? _activeMatch;
  StreamSubscription? _slotMatchSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPolling();
    });
  }

  void _initPolling() async {
    final slotProvider = context.read<SlotProvider>();
    final watchProvider = context.read<WatchProvider>();
    final settings = context.read<SettingsProvider>();
    final polling = context.read<PollingService>();

    polling.setProviders(slotProvider, watchProvider);
    polling.setInterval(settings.pollIntervalMinutes);

    _slotMatchSubscription = polling.onSlotFound.listen((match) {
      if (mounted) {
        setState(() => _activeMatch = match);
      }
    });

    await watchProvider.loadWatches();

    polling.start();
  }

  @override
  void dispose() {
    _slotMatchSubscription?.cancel();
    context.read<PollingService>().stop();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const HomeScreen(),
        if (_activeMatch != null)
          CountdownAlertOverlay(
            slot: _activeMatch!.slot,
            sessionType: _activeMatch!.sessionType,
            bookingUrl: _activeMatch!.bookingUrl,
            onDismiss: () => setState(() => _activeMatch = null),
          ),
      ],
    );
  }
}

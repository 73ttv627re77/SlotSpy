import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:home_widget/home_widget.dart';

import 'theme/slotspy_dark_theme.dart';
import 'services/database_service.dart';
import 'services/rpde_service.dart';
import 'services/notification_service.dart';
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
  final rpde = RpdeService(db);
  final notifications = NotificationService();

  await notifications.initialize();
  await notifications.requestPermissions();

  // Initialize home widget
  await _initHomeWidget();

  runApp(
    SlotSpyApp(
      prefs: prefs,
      db: db,
      rpde: rpde,
      notifications: notifications,
    ),
  );
}

Future<void> _initHomeWidget() async {
  try {
    // Set the app group ID for iOS widget data sharing
    // NOTE: Native iOS setup required — see lib/data/gym_link_bank.dart
    await HomeWidget.setAppGroupId('group.com.slotspy.app');
  } catch (_) {
    // Widget not available on this platform
  }
}

class SlotSpyApp extends StatelessWidget {
  final SharedPreferences prefs;
  final DatabaseService db;
  final RpdeService rpde;
  final NotificationService notifications;

  const SlotSpyApp({
    super.key,
    required this.prefs,
    required this.db,
    required this.rpde,
    required this.notifications,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => WatchProvider(db, rpde, notifications),
        ),
        ChangeNotifierProvider(
          create: (_) => SlotProvider(db, rpde),
        ),
        ChangeNotifierProxyProvider<WatchProvider, PollingService>(
          create: (_) => PollingService(db, rpde, notifications),
          update: (_, watchProvider, pollingService) {
            pollingService?.setProviders(
              Provider.of<SlotProvider>(_, listen: false),
              watchProvider,
            );
            return pollingService ?? PollingService(db, rpde, notifications);
          },
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          // Handle wakelock based on settings
          _updateWakelock(settings.keepAwakeEnabled);

          return MaterialApp(
            title: 'SlotSpy',
            debugShowCheckedModeBanner: false,
            theme: SlotSpyDarkTheme.theme,
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
    // Yield immediately so the first frame renders without being blocked
    // by async init work (DB loads, polling setup).
    await Future.microtask(() {});

    final slotProvider = context.read<SlotProvider>();
    final watchProvider = context.read<WatchProvider>();
    final settings = context.read<SettingsProvider>();
    final polling = context.read<PollingService>();

    polling.setProviders(slotProvider, watchProvider);
    polling.setInterval(settings.pollIntervalMinutes);

    // Subscribe to slot matches
    _slotMatchSubscription = polling.onSlotFound.listen((match) {
      if (mounted) {
        setState(() => _activeMatch = match);
      }
    });

    // Load cached data first
    await slotProvider.loadCachedSessionSeries();
    await slotProvider.loadCachedSlots();
    await watchProvider.loadWatches();

    // Start polling — first poll fires after interval, not immediately
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

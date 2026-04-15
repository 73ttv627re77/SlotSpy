import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  runApp(
    SlotSpyApp(
      prefs: prefs,
      db: db,
      rpde: rpde,
      notifications: notifications,
    ),
  );
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
          return MaterialApp(
            title: 'SlotSpy',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0F62FE),
                brightness: Brightness.light,
              ),
              scaffoldBackgroundColor: const Color(0xFFF5F7FA),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: Color(0xFF1A1A2E),
                elevation: 0,
                centerTitle: false,
              ),
              useMaterial3: true,
            ),
            home: const MainNavigator(),
          );
        },
      ),
    );
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

    // Start polling
    polling.start();
  }

  @override
  void dispose() {
    _slotMatchSubscription?.cancel();
    context.read<PollingService>().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const HomeScreen(),
        if (_activeMatch != null)
          AlertOverlay(
            slot: _activeMatch!.slot,
            sessionType: _activeMatch!.sessionType,
            onDismiss: () => setState(() => _activeMatch = null),
          ),
      ],
    );
  }
}

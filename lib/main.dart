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
import 'services/backend_service.dart';
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
  final backendUrl = prefs.getString('backend_url');
  final useCustomBackend = prefs.getBool('use_custom_backend') ?? false;
  final backend = (useCustomBackend && backendUrl != null && backendUrl.isNotEmpty)
      ? BackendService(backendUrl)
      : null;
  // Pass backendUrl to RpdeService only when custom backend is enabled so
  // the legacy _fetchFromCustomBackend path is also guarded by the toggle.
  final rpde = RpdeService(useCustomBackend ? backendUrl : null, db);
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
  final RpdeService rpde;
  final NotificationService notifications;
  final BackendService? backend;

  const SlotSpyApp({
    super.key,
    required this.prefs,
    required this.db,
    required this.rpde,
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
          create: (_) => WatchProvider(db, rpde, notifications, backend),
        ),
        ChangeNotifierProvider(
          create: (_) => SlotProvider(db, rpde, backend),
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
  bool _sessionTypesLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPolling();
    });
  }

  void _initPolling() async {
    await Future.microtask(() {});

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

    await slotProvider.loadCachedSlots();
    await watchProvider.loadWatches();

    final hasCache = await slotProvider.hasSessionTypesCache();
    if (!hasCache) {
      if (mounted) setState(() => _sessionTypesLoading = true);
      // Start a periodic timer to drive UI updates while loading
      Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (!_sessionTypesLoading) {
          timer.cancel();
          return;
        }
        setState(() {});
      });
      try {
        await slotProvider.fetchAndCacheAllSessionTypesParallel(
          onProgress: (pageFetched, totalPages, gymsFound) {
            slotProvider.updateFetchProgress(pageFetched, totalPages, gymsFound);
          },
        );
      } catch (_) {
        // Error is captured in slotProvider.fetchError
      }
      if (mounted) setState(() => _sessionTypesLoading = false);
    } else {
      await slotProvider.loadSessionTypesFromCache();
    }

    polling.start();
  }

  void _retrySessionTypesFetch() async {
    if (!mounted) return;
    setState(() => _sessionTypesLoading = true);
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_sessionTypesLoading) {
        timer.cancel();
        return;
      }
      setState(() {});
    });
    try {
      await context.read<SlotProvider>().fetchAndCacheAllSessionTypesParallel(
        onProgress: (pageFetched, totalPages, gymsFound) {
          context.read<SlotProvider>().updateFetchProgress(pageFetched, totalPages, gymsFound);
        },
      );
    } catch (_) {}
    if (mounted) setState(() => _sessionTypesLoading = false);
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
    final slotProvider = context.watch<SlotProvider>();
    final pagesFetched = slotProvider.fetchPagesFetched;
    final totalPages = slotProvider.fetchTotalPages;
    final gymsFound = slotProvider.fetchGymsFound;

    final showProgress = _sessionTypesLoading && totalPages > 0;
    final progressLabel = totalPages > 0
        ? '$pagesFetched / $totalPages pages \u00b7 $gymsFound gyms found'
        : null;

    final hasError = slotProvider.fetchError != null && !_sessionTypesLoading;
    final errorMessage = slotProvider.fetchError;

    return Stack(
      children: [
        const HomeScreen(),
        if (_sessionTypesLoading)
          DefaultTextStyle.merge(
            style: const TextStyle(decoration: TextDecoration.none),
            child: Container(
            color: const Color(0xFF0D0D0F).withValues(alpha: 0.92),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF2A2A2A),
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 40,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Radar icon + ring animation
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer pulsing ring
                          SizedBox(
                            width: 72,
                            height: 72,
                            child: CircularProgressIndicator(
                              color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                              strokeWidth: 2,
                            ),
                          ),
                          // Inner spinner
                          const SizedBox(
                            width: 52,
                            height: 52,
                            child: CircularProgressIndicator(
                              color: Color(0xFF6C5CE7),
                              strokeWidth: 3,
                            ),
                          ),
                          // Radar dot
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C5CE7),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.6),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Discovering gyms',
                      style: TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (showProgress) ...[
                      Text(
                        progressLabel!,
                        style: const TextStyle(
                          color: Color(0xFFB0B0B0),
                          fontSize: 13,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Rounded progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 240,
                          height: 6,
                          child: LinearProgressIndicator(
                            value: pagesFetched / totalPages,
                            backgroundColor: const Color(0xFF3A3A4A),
                            valueColor: const AlwaysStoppedAnimation(Color(0xFF6C5CE7)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (!showProgress && !hasError)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Finding sessions near you...',
                          style: TextStyle(
                            color: Color(0xFF909090),
                            fontSize: 13,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    if (hasError) ...[
                      const SizedBox(height: 4),
                      Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFF6B6B),
                          fontSize: 12,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _retrySessionTypesFetch,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C5CE7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Retry',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // Subtle badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Background process · won\'t interrupt you',
                        style: TextStyle(
                          color: Color(0xFF808080),
                          fontSize: 11,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),
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

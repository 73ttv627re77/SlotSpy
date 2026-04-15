import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/slot.dart';
import '../models/session_type.dart';
import '../providers/watch_provider.dart';
import '../theme/slotspy_dark_theme.dart';

class CountdownAlertOverlay extends StatefulWidget {
  final Slot slot;
  final SessionType? sessionType;
  final String bookingUrl;
  final VoidCallback onDismiss;

  const CountdownAlertOverlay({
    super.key,
    required this.slot,
    required this.sessionType,
    required this.bookingUrl,
    required this.onDismiss,
  });

  @override
  State<CountdownAlertOverlay> createState() => _CountdownAlertOverlayState();
}

class _CountdownAlertOverlayState extends State<CountdownAlertOverlay>
    with SingleTickerProviderStateMixin {
  late int _totalSeconds;
  late int _remainingSeconds;
  late double _progress;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _autoOpenEnabled = true;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _totalSeconds = settings.countdownDurationSeconds;
    _remainingSeconds = _totalSeconds;
    _autoOpenEnabled = settings.autoOpenBookingEnabled;
    _progress = 1.0;

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _remainingSeconds--;
        _progress = _remainingSeconds / _totalSeconds;
      });
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _autoOpen();
      }
    });
  }

  Future<void> _autoOpen() async {
    if (_autoOpenEnabled) {
      await _openBookingUrl();
    }
    widget.onDismiss();
  }

  Future<void> _openBookingUrl() async {
    final url = widget.bookingUrl.isNotEmpty
        ? widget.bookingUrl
        : (widget.sessionType?.url ?? 'https://www.everyoneactive.com/');
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    }
  }

  void _cancel() {
    _timer?.cancel();
    widget.onDismiss();
  }

  Color get _progressBarColor {
    if (_remainingSeconds <= 10) {
      return SlotSpyDarkTheme.danger;
    }
    return SlotSpyDarkTheme.warning;
  }

  String get _progressBarString {
    final filled = (_progress * 10).round();
    final empty = 10 - filled;
    return '[' + '█' * filled + '─' * empty + ']';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: SlotSpyDarkTheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: SlotSpyDarkTheme.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Emoji header
                const Text(
                  '🎉',
                  style: TextStyle(fontSize: 64),
                ),
                const SizedBox(height: 12),
                // "SLOT AVAILABLE!" header
                const Text(
                  'SLOT AVAILABLE!',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: SlotSpyDarkTheme.primary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 24),

                // Session name
                Text(
                  widget.sessionType?.name ?? 'Session',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: SlotSpyDarkTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),

                // Gym name
                Text(
                  widget.sessionType?.gym.name ?? 'Gym',
                  style: const TextStyle(
                    fontSize: 15,
                    color: SlotSpyDarkTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Date/time card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SlotSpyDarkTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 18, color: SlotSpyDarkTheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            widget.slot.formattedDate,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: SlotSpyDarkTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.access_time,
                              size: 18, color: SlotSpyDarkTheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            widget.slot.formattedTime,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: SlotSpyDarkTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      if (widget.sessionType?.price != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '£${widget.sessionType!.price!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: SlotSpyDarkTheme.success,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Countdown display
                Column(
                  children: [
                    Text(
                      'Book in: $_progressBarString ${_remainingSeconds}s',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        color: _progressBarColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: SlotSpyDarkTheme.surfaceLight,
                        valueColor: AlwaysStoppedAnimation<Color>(_progressBarColor),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // BOOK NOW button with pulse animation
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _timer?.cancel();
                        _openBookingUrl();
                        widget.onDismiss();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SlotSpyDarkTheme.success,
                        foregroundColor: SlotSpyDarkTheme.background,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'BOOK NOW →',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Cancel button
                TextButton(
                  onPressed: _cancel,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: SlotSpyDarkTheme.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

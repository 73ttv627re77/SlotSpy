import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/watch_provider.dart';
import '../theme/slotspy_dark_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SlotSpyDarkTheme.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: SlotSpyDarkTheme.surface,
        elevation: 0,
        foregroundColor: SlotSpyDarkTheme.textPrimary,
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionHeader('Polling'),
              _Card(
                child: ListTile(
                  leading:
                      const Icon(Icons.timer, color: SlotSpyDarkTheme.primary),
                  title: const Text('Poll interval'),
                  subtitle: Text(
                    'Every ${settings.pollIntervalMinutes} minute${settings.pollIntervalMinutes > 1 ? 's' : ''}',
                    style: const TextStyle(color: SlotSpyDarkTheme.textSecondary),
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      color: SlotSpyDarkTheme.textMuted),
                  onTap: () => _showPollIntervalPicker(context, settings),
                ),
              ),
              const SizedBox(height: 24),
              _SectionHeader('Alert'),
              _Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.volume_up,
                          color: SlotSpyDarkTheme.primary),
                      title: const Text('Alert sound'),
                      subtitle: const Text('Play a sound when a slot is found',
                          style: TextStyle(color: SlotSpyDarkTheme.textSecondary)),
                      value: settings.alertSoundEnabled,
                      onChanged: (v) => settings.setAlertSound(v),
                      activeColor: SlotSpyDarkTheme.primary,
                    ),
                    const Divider(height: 1, color: SlotSpyDarkTheme.surfaceLight),
                    SwitchListTile(
                      secondary: const Icon(Icons.open_in_browser,
                          color: SlotSpyDarkTheme.primary),
                      title: const Text('Auto-open booking'),
                      subtitle: const Text(
                          'Open booking URL automatically when countdown ends',
                          style: TextStyle(color: SlotSpyDarkTheme.textSecondary)),
                      value: settings.autoOpenBookingEnabled,
                      onChanged: (v) => settings.setAutoOpenBooking(v),
                      activeColor: SlotSpyDarkTheme.primary,
                    ),
                    const Divider(height: 1, color: SlotSpyDarkTheme.surfaceLight),
                    ListTile(
                      leading: const Icon(Icons.timer,
                          color: SlotSpyDarkTheme.primary),
                      title: const Text('Countdown duration'),
                      subtitle: Text(
                        '${settings.countdownDurationSeconds} seconds',
                        style:
                            const TextStyle(color: SlotSpyDarkTheme.textSecondary),
                      ),
                      trailing: const Icon(Icons.chevron_right,
                          color: SlotSpyDarkTheme.textMuted),
                      onTap: () =>
                          _showCountdownDurationPicker(context, settings),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionHeader('Display'),
              _Card(
                child: SwitchListTile(
                  secondary:
                      const Icon(Icons.lightbulb_outline, color: SlotSpyDarkTheme.primary),
                  title: const Text('Keep screen on'),
                  subtitle: const Text(
                      'Prevent screen from sleeping while app is open',
                      style: TextStyle(color: SlotSpyDarkTheme.textSecondary)),
                  value: settings.keepAwakeEnabled,
                  onChanged: (v) => settings.setKeepAwake(v),
                  activeColor: SlotSpyDarkTheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              _SectionHeader('Widget'),
              _Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.widgets, color: SlotSpyDarkTheme.primary),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Home Screen Widget',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: SlotSpyDarkTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'See your watch status at a glance without opening the app.',
                        style: TextStyle(
                          color: SlotSpyDarkTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: SlotSpyDarkTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '⚠️ Native setup required',
                              style: TextStyle(
                                color: SlotSpyDarkTheme.warning,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '1. Open ios/Runner.xcworkspace in Xcode\n'
                              '2. Add a WidgetKit target (File > New > Target > Widget Extension)\n'
                              '3. Set App Group to "group.com.slotspy.app" in both targets\n'
                              '4. Configure the widget in Swift using SlotSpyWidget.swift\n'
                              '5. The app writes widget data via the home_widget package',
                              style: TextStyle(
                                color: SlotSpyDarkTheme.textSecondary,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _SectionHeader('Data'),
              _Card(
                child: ListTile(
                  leading: Icon(Icons.delete_sweep,
                      color: SlotSpyDarkTheme.danger.withValues(alpha: 0.8)),
                  title: const Text('Clear all watches'),
                  subtitle: const Text('Remove all saved watches',
                      style: TextStyle(color: SlotSpyDarkTheme.textSecondary)),
                  onTap: () => _confirmClearWatches(context),
                ),
              ),
              const SizedBox(height: 24),
              _SectionHeader('About'),
              _Card(
                child: Column(
                  children: [
                    const ListTile(
                      leading:
                          Icon(Icons.info_outline, color: SlotSpyDarkTheme.primary),
                      title: Text('SlotSpy'),
                      subtitle: Text('Version 1.0.0',
                          style: TextStyle(color: SlotSpyDarkTheme.textSecondary)),
                    ),
                    const Divider(height: 1, color: SlotSpyDarkTheme.surfaceLight),
                    const ListTile(
                      leading: Icon(Icons.api, color: SlotSpyDarkTheme.primary),
                      title: Text('OpenActive'),
                      subtitle: Text('Data powered by OpenActive',
                          style: TextStyle(color: SlotSpyDarkTheme.textSecondary)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  void _showPollIntervalPicker(
      BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SlotSpyDarkTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Poll Interval',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: SlotSpyDarkTheme.textPrimary,
                ),
              ),
            ),
            ...[1, 2, 5].map((mins) {
              return RadioListTile<int>(
                title: Text(
                  '$mins minute${mins > 1 ? 's' : ''}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: SlotSpyDarkTheme.textPrimary),
                ),
                value: mins,
                groupValue: settings.pollIntervalMinutes,
                activeColor: SlotSpyDarkTheme.primary,
                onChanged: (v) {
                  if (v != null) {
                    settings.setPollInterval(v);
                    context.read<PollingService>().setInterval(v);
                    Navigator.pop(ctx);
                  }
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showCountdownDurationPicker(
      BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SlotSpyDarkTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Countdown Duration',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: SlotSpyDarkTheme.textPrimary,
                ),
              ),
            ),
            ...[15, 30, 60].map((secs) {
              return RadioListTile<int>(
                title: Text(
                  '$secs seconds',
                  style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: SlotSpyDarkTheme.textPrimary),
                ),
                value: secs,
                groupValue: settings.countdownDurationSeconds,
                activeColor: SlotSpyDarkTheme.primary,
                onChanged: (v) {
                  if (v != null) {
                    settings.setCountdownDuration(v);
                    Navigator.pop(ctx);
                  }
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _confirmClearWatches(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SlotSpyDarkTheme.surface,
        title: const Text(
          'Clear All Watches?',
          style: TextStyle(color: SlotSpyDarkTheme.textPrimary),
        ),
        content: const Text(
          'This will remove all your saved watches. This action cannot be undone.',
          style: TextStyle(color: SlotSpyDarkTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<WatchProvider>().clearAllWatches();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All watches cleared')),
              );
            },
            style: TextButton.styleFrom(
                foregroundColor: SlotSpyDarkTheme.danger),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: SlotSpyDarkTheme.textMuted,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SlotSpyDarkTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

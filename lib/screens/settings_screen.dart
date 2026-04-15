import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/watch_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionHeader('Polling'),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.timer, color: Color(0xFF0F62FE)),
                      title: const Text('Poll interval'),
                      subtitle: Text(
                        'Every ${settings.pollIntervalMinutes} minute${settings.pollIntervalMinutes > 1 ? 's' : ''}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showPollIntervalPicker(context, settings),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionHeader('Notifications'),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary:
                          const Icon(Icons.volume_up, color: Color(0xFF0F62FE)),
                      title: const Text('Alert sound'),
                      subtitle: const Text('Play a sound when a slot is found'),
                      value: settings.alertSoundEnabled,
                      onChanged: (v) => settings.setAlertSound(v),
                      activeColor: const Color(0xFF0F62FE),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.lightbulb_outline,
                          color: Color(0xFF0F62FE)),
                      title: const Text('Keep screen awake'),
                      subtitle:
                          const Text('Prevent screen from sleeping while app is open'),
                      value: settings.keepAwakeEnabled,
                      onChanged: (v) => settings.setKeepAwake(v),
                      activeColor: const Color(0xFF0F62FE),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionHeader('Data'),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.delete_sweep,
                          color: Colors.red.shade400),
                      title: const Text('Clear all watches'),
                      subtitle: const Text('Remove all saved watches'),
                      onTap: () => _confirmClearWatches(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionHeader('About'),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.info_outline, color: Color(0xFF0F62FE)),
                      title: Text('SlotSpy'),
                      subtitle: Text('Version 1.0.0'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.api, color: Color(0xFF0F62FE)),
                      title: const Text('OpenActive'),
                      subtitle: const Text('Data powered by OpenActive'),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPollIntervalPicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
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
                ),
              ),
            ),
            ...[1, 2, 5].map((mins) {
              return RadioListTile<int>(
                title: Text(
                  '$mins minute${mins > 1 ? 's' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                value: mins,
                groupValue: settings.pollIntervalMinutes,
                activeColor: const Color(0xFF0F62FE),
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

  void _confirmClearWatches(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Watches?'),
        content: const Text(
          'This will remove all your saved watches. This action cannot be undone.',
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

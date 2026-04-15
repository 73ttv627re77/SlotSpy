import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/watch_provider.dart';
import '../models/watch.dart';
import '../theme/slotspy_dark_theme.dart';
import 'add_watch_screen.dart';
import 'live_slots_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WatchProvider>().loadWatches();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SlotSpyDarkTheme.background,
      appBar: AppBar(
        title: const Text(
          'SlotSpy',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: SlotSpyDarkTheme.textPrimary,
          ),
        ),
        backgroundColor: SlotSpyDarkTheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.radar, color: SlotSpyDarkTheme.primary),
            onPressed: () => _openLiveSlots(context),
            tooltip: 'Live Slots',
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: SlotSpyDarkTheme.textSecondary),
            onPressed: () => _openSettings(context),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Consumer<WatchProvider>(
        builder: (context, provider, _) {
          if (provider.loading) {
            return const Center(
              child: CircularProgressIndicator(color: SlotSpyDarkTheme.primary),
            );
          }

          if (provider.watches.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.watches.length,
            itemBuilder: (context, index) {
              final watch = provider.watches[index];
              return _WatchCard(
                watch: watch,
                onToggle: () => provider.toggleWatch(watch.id),
                onDelete: () => _confirmDelete(context, provider, watch),
                onEdit: () => _editWatch(context, watch),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addWatch(context),
        backgroundColor: SlotSpyDarkTheme.primary,
        icon: const Icon(Icons.add, color: SlotSpyDarkTheme.background),
        label: const Text(
          'Add Watch',
          style: TextStyle(
              color: SlotSpyDarkTheme.background, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.radar,
              size: 80,
              color: SlotSpyDarkTheme.textMuted,
            ),
            const SizedBox(height: 24),
            const Text(
              'No watches yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: SlotSpyDarkTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Add a watch to get notified when gym slots become available',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: SlotSpyDarkTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _addWatch(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: SlotSpyDarkTheme.primary,
                foregroundColor: SlotSpyDarkTheme.background,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text(
                'Add Your First Watch',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addWatch(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddWatchScreen(),
      ),
    );
  }

  void _editWatch(BuildContext context, Watch watch) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddWatchScreen(watchToEdit: watch),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WatchProvider provider, Watch watch) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SlotSpyDarkTheme.surface,
        title: const Text(
          'Delete Watch?',
          style: TextStyle(color: SlotSpyDarkTheme.textPrimary),
        ),
        content: const Text(
          'This action cannot be undone.',
          style: TextStyle(color: SlotSpyDarkTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteWatch(watch.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(
                foregroundColor: SlotSpyDarkTheme.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openLiveSlots(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LiveSlotsScreen(),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }
}

class _WatchCard extends StatelessWidget {
  final Watch watch;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _WatchCard({
    required this.watch,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(watch.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: SlotSpyDarkTheme.danger.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: SlotSpyDarkTheme.surface,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: watch.enabled
                        ? SlotSpyDarkTheme.primary.withValues(alpha: 0.15)
                        : SlotSpyDarkTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.radar,
                    color: watch.enabled
                        ? SlotSpyDarkTheme.primary
                        : SlotSpyDarkTheme.textMuted,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        watch.sessionNamePattern?.isNotEmpty == true
                            ? watch.sessionNamePattern!
                            : 'Any session',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: watch.enabled
                              ? SlotSpyDarkTheme.textPrimary
                              : SlotSpyDarkTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        watch.summary,
                        style: const TextStyle(
                          color: SlotSpyDarkTheme.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: watch.enabled,
                  onChanged: (_) => onToggle(),
                  activeColor: SlotSpyDarkTheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

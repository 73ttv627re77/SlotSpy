import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/watch_provider.dart';
import '../models/slot.dart';
import '../models/session_type.dart';

class LiveSlotsScreen extends StatefulWidget {
  const LiveSlotsScreen({super.key});

  @override
  State<LiveSlotsScreen> createState() => _LiveSlotsScreenState();
}

class _LiveSlotsScreenState extends State<LiveSlotsScreen> {
  bool _showWatchedOnly = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    await context.read<SlotProvider>().fetchSlots();
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Live Slots'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
        actions: [
          IconButton(
            icon: Icon(
              _showWatchedOnly ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: _showWatchedOnly
                  ? const Color(0xFF0F62FE)
                  : const Color(0xFF6B7280),
            ),
            onPressed: () =>
                setState(() => _showWatchedOnly = !_showWatchedOnly),
            tooltip: 'Filter by watched gyms',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF6B7280)),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Consumer<SlotProvider>(
        builder: (context, provider, _) {
          if (provider.loading && provider.slots.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F62FE)),
            );
          }

          if (provider.error != null && provider.slots.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load slots',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _refresh,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F62FE),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          var slots = provider.availableSlots;
          if (_showWatchedOnly) {
            final watchedGymIds = context
                .read<WatchProvider>()
                .activeWatches
                .where((w) => w.gymId != null)
                .map((w) => w.gymId)
                .toSet();
            slots = slots.where((slot) {
              final st = provider.getSessionTypeForSlot(slot);
              return st != null && watchedGymIds.contains(st.gym.id);
            }).toList();
          }

          if (slots.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy,
                              size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'No available slots right now',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pull down to refresh',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Group by gym
          final grouped = <String, List<Slot>>{};
          for (final slot in slots) {
            final st = provider.getSessionTypeForSlot(slot);
            final key = st?.gym.name ?? 'Unknown Gym';
            grouped.putIfAbsent(key, () => []).add(slot);
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final gymName = grouped.keys.elementAt(index);
                final gymSlots = grouped[gymName]!;
                return _GymSlotGroup(
                  gymName: gymName,
                  slots: gymSlots,
                  getSessionType: provider.getSessionTypeForSlot,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _GymSlotGroup extends StatelessWidget {
  final String gymName;
  final List<Slot> slots;
  final SessionType? Function(Slot) getSessionType;

  const _GymSlotGroup({
    required this.gymName,
    required this.slots,
    required this.getSessionType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.location_on,
                  size: 18, color: Color(0xFF0F62FE)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  gymName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
              Text(
                '${slots.length} slot${slots.length > 1 ? 's' : ''}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        ...slots.map((slot) {
          final st = getSessionType(slot);
          return _SlotCard(slot: slot, sessionType: st);
        }),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SlotCard extends StatelessWidget {
  final Slot slot;
  final SessionType? sessionType;

  const _SlotCard({required this.slot, required this.sessionType});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sessionType?.name ?? 'Session',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        slot.formattedDate,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.access_time,
                          size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        slot.formattedTime,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  if (sessionType?.price != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '£${sessionType!.price!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F62FE),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _bookSlot(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F62FE),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text(
                'Book Now',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bookSlot(BuildContext context) async {
    final url = sessionType?.url ?? 'https://www.everyoneactive.com/';
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open $url'),
            action: SnackBarAction(
              label: 'Copy',
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }
}

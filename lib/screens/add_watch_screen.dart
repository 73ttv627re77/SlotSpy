import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/watch_provider.dart';
import '../models/watch.dart';
import '../models/gym.dart';
import '../models/session_type.dart';
import '../theme/slotspy_dark_theme.dart';
import '../data/venue_database.dart';

class AddWatchScreen extends StatefulWidget {
  final Watch? watchToEdit;

  const AddWatchScreen({super.key, this.watchToEdit});

  @override
  State<AddWatchScreen> createState() => _AddWatchScreenState();
}

class _AddWatchScreenState extends State<AddWatchScreen> {
  int _currentStep = 0;
  Gym? _selectedGym;
  String _gymSearchQuery = '';
  bool _watchAllSessions = false;
  Set<String> _selectedSessionPatterns = {};
  Set<int> _selectedDays = {};
  TimeOfDay? _earliestTime;
  TimeOfDay? _latestTime;
  bool _notificationsEnabled = true;

  bool get _isEditing => widget.watchToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final w = widget.watchToEdit!;
      _selectedGym = _findGymById(w.gymId);
      _selectedDays = w.daysOfWeek ?? {};
      _earliestTime = w.earliestTime != null
          ? TimeOfDay(hour: w.earliestTime!.hour, minute: w.earliestTime!.minute)
          : null;
      _latestTime = w.latestTime != null
          ? TimeOfDay(hour: w.latestTime!.hour, minute: w.latestTime!.minute)
          : null;
      _notificationsEnabled = w.notificationsEnabled;
      if (w.sessionPatterns != null && w.sessionPatterns!.isNotEmpty) {
        _selectedSessionPatterns = w.sessionPatterns!.toSet();
        _watchAllSessions = false;
      } else if (w.sessionNamePattern != null && w.sessionNamePattern!.isNotEmpty) {
        // Backward compat: single pattern from legacy watch
        _selectedSessionPatterns = {w.sessionNamePattern!};
        _watchAllSessions = false;
      } else {
        _watchAllSessions = true; // no specific sessions → watch all
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SlotProvider>().loadCachedSessionSeries();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SlotProvider>().loadCachedSessionSeries();
      });
    }
  }

  Gym? _findGymById(String? id) {
    if (id == null) return null;
    final provider = context.read<SlotProvider>();
    try {
      return provider.gyms.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Static gyms from the pre-baked database — available immediately.
  List<Gym> get _staticGyms {
    if (_gymSearchQuery.isEmpty) return VenueDatabase.gyms;
    final q = _gymSearchQuery.toLowerCase();
    return VenueDatabase.gyms.where((g) {
      return g.name.toLowerCase().contains(q) ||
          g.address.toLowerCase().contains(q);
    }).toList();
  }

  /// All gyms shown in step 1: static DB gyms + API gyms (deduplicated by name).
  List<Gym> get _filteredGyms {
    final provider = context.read<SlotProvider>();
    // Start with static gyms
    final staticGyms = _staticGyms;
    // Build set of static gym names for dedup
    final staticNames = staticGyms.map((g) => g.name.toLowerCase()).toSet();
    // Add API gyms that aren't duplicates
    final apiGyms = provider.gyms
        .where((g) => !staticNames.contains(g.name.toLowerCase()))
        .toList();
    return [...staticGyms, ...apiGyms];
  }

  /// Sessions visible for the selected gym.
  /// For static DB gyms (Everyone Active / Better), matches by name.
  /// For API gyms, matches by id.
  List<SessionType> get _sessionsAtSelectedGym {
    if (_selectedGym == null) return [];
    final provider = context.read<SlotProvider>();
    final gym = _selectedGym!;
    if (gym.provider == 'everyoneactive' || gym.provider == 'better') {
      // Static gym — match by name
      final q = gym.name.toLowerCase();
      return provider.sessionTypes
          .where((st) => st.gym.name.toLowerCase() == q)
          .toList();
    }
    // API gym — match by id
    return provider.sessionTypes.where((st) => st.gym.id == gym.id).toList();
  }

  int _sessionCountForGym(Gym gym, List<SessionType> allSessions) {
    return allSessions.where((st) => st.gym.id == gym.id).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SlotSpyDarkTheme.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Watch' : 'New Watch'),
        backgroundColor: SlotSpyDarkTheme.surface,
        elevation: 0,
        foregroundColor: SlotSpyDarkTheme.textPrimary,
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _onContinue,
        onStepCancel: _onCancel,
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                if (_currentStep < 3)
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SlotSpyDarkTheme.primary,
                      foregroundColor: SlotSpyDarkTheme.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Continue'),
                  )
                else
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SlotSpyDarkTheme.primary,
                      foregroundColor: SlotSpyDarkTheme.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(_isEditing ? 'Save Changes' : 'Create Watch'),
                  ),
                const SizedBox(width: 12),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Gym',
                style: TextStyle(color: SlotSpyDarkTheme.textPrimary)),
            subtitle: Text(
              _selectedGym?.name ?? 'Any gym',
              style: const TextStyle(color: SlotSpyDarkTheme.textSecondary),
            ),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: _buildGymStep(),
          ),
          Step(
            title: const Text('Session',
                style: TextStyle(color: SlotSpyDarkTheme.textPrimary)),
            subtitle: Text(
              _watchAllSessions
                  ? 'Watch all sessions'
                  : _selectedSessionPatterns.isEmpty
                      ? 'Any session'
                      : '${_selectedSessionPatterns.length} session(s)',
              style: const TextStyle(color: SlotSpyDarkTheme.textSecondary),
            ),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: _buildSessionStep(),
          ),
          Step(
            title: const Text('Time Preferences',
                style: TextStyle(color: SlotSpyDarkTheme.textPrimary)),
            subtitle: Text(
              _getTimePrefsSummary(),
              style: const TextStyle(color: SlotSpyDarkTheme.textSecondary),
            ),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            content: _buildTimePrefsStep(),
          ),
          Step(
            title: const Text('Review & Save',
                style: TextStyle(color: SlotSpyDarkTheme.textPrimary)),
            subtitle: const Text('Review your watch',
                style: TextStyle(color: SlotSpyDarkTheme.textSecondary)),
            isActive: _currentStep >= 3,
            state: StepState.indexed,
            content: _buildReviewStep(),
          ),
        ],
      ),
    );
  }

  Widget _buildGymStep() {
    return Consumer<SlotProvider>(
      builder: (context, provider, _) {
        final allSessions = provider.sessionTypes;
        final gyms = _filteredGyms;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              autocorrect: false,
              enableSuggestions: false,
              spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
              decoration: InputDecoration(
                hintText: 'Search gyms by name...',
                hintStyle: const TextStyle(color: Color(0xFF8A8A8A)),
                prefixIcon:
                    const Icon(Icons.search, color: Color(0xFF8A8A8A)),
                filled: true,
                fillColor: SlotSpyDarkTheme.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: SlotSpyDarkTheme.primary, width: 1.5),
                ),
              ),
              style: const TextStyle(color: SlotSpyDarkTheme.textPrimary),
              onChanged: (v) => setState(() => _gymSearchQuery = v),
            ),
            const SizedBox(height: 16),
            // "Any gym" option
            Card(
              elevation: 0,
              color: _selectedGym == null
                  ? SlotSpyDarkTheme.primary.withValues(alpha: 0.15)
                  : SlotSpyDarkTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: _selectedGym == null
                    ? const BorderSide(color: SlotSpyDarkTheme.primary)
                    : BorderSide.none,
              ),
              child: ListTile(
                title: const Text('Any gym',
                    style: TextStyle(color: SlotSpyDarkTheme.textPrimary)),
                subtitle: const Text('Match any gym',
                    style: TextStyle(color: SlotSpyDarkTheme.textSecondary)),
                trailing: _selectedGym == null
                    ? const Icon(Icons.check_circle, color: SlotSpyDarkTheme.primary)
                    : null,
                onTap: () => setState(() {
                  _selectedGym = null;
                  _watchAllSessions = true;
                  _selectedSessionPatterns = {};
                  if (_currentStep == 0) {
                    _currentStep = 1;
                  }
                }),
              ),
            ),
            const Divider(color: SlotSpyDarkTheme.surfaceLight),
            ...gyms.map((gym) {
              final isSelected = _selectedGym?.id == gym.id;
              // Count API sessions for this gym
              final count = gym.provider == 'everyoneactive' || gym.provider == 'better'
                  ? provider.sessionsAtGym(gym.name, gym.provider).length
                  : _sessionCountForGym(gym, allSessions);
              return Card(
                elevation: 0,
                color: isSelected
                    ? SlotSpyDarkTheme.primary.withValues(alpha: 0.15)
                    : SlotSpyDarkTheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isSelected
                      ? const BorderSide(color: SlotSpyDarkTheme.primary)
                      : BorderSide.none,
                ),
                child: ListTile(
                  title: Text(gym.name,
                      style:
                          const TextStyle(color: SlotSpyDarkTheme.textPrimary)),
                  subtitle: Text(
                    '${gym.address}${gym.provider != null ? ' • ${gym.provider!}' : ''}',
                    style: const TextStyle(color: SlotSpyDarkTheme.textSecondary)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$count',
                        style: const TextStyle(
                            color: SlotSpyDarkTheme.textSecondary)),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle,
                            color: SlotSpyDarkTheme.primary),
                      ],
                    ],
                  ),
                  onTap: () => setState(() {
                    _selectedGym = gym;
                    _watchAllSessions = false;
                    _selectedSessionPatterns = {};
                    // Auto-advance to session step
                    if (_currentStep == 0) {
                      _currentStep = 1;
                    }
                  }),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildSessionStep() {
    if (_selectedGym == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Pick a specific gym to select sessions.',
          style: TextStyle(color: SlotSpyDarkTheme.textSecondary),
        ),
      );
    }
    return _SessionStepContent(
      key: ValueKey(_selectedGym!.id),
      gym: _selectedGym!,
      watchAllSessions: _watchAllSessions,
      selectedSessionPatterns: _selectedSessionPatterns,
      onWatchAllSessionsChanged: (v) => setState(() {
        _watchAllSessions = v ?? false;
        if (_watchAllSessions) {
          _selectedSessionPatterns = {};
        }
        if (_currentStep == 1) _currentStep = 2;
      }),
      onSessionPatternToggled: (name) => setState(() {
        _watchAllSessions = false;
        if (_selectedSessionPatterns.contains(name)) {
          _selectedSessionPatterns.remove(name);
        } else {
          _selectedSessionPatterns.add(name);
        }
        if (_currentStep == 1) _currentStep = 2;
      }),
    );
  }

  Widget _buildTimePrefsStep() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Days of Week (leave empty for any day)',
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: SlotSpyDarkTheme.textPrimary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: List.generate(7, (i) {
            final day = i + 1;
            final selected = _selectedDays.contains(day);
            return FilterChip(
              label: Text(days[i]),
              selected: selected,
              onSelected: (v) {
                setState(() {
                  if (v) {
                    _selectedDays.add(day);
                  } else {
                    _selectedDays.remove(day);
                  }
                  if (_currentStep == 2) _currentStep = 3;
                });
              },
              selectedColor: SlotSpyDarkTheme.primary.withValues(alpha: 0.2),
              checkmarkColor: SlotSpyDarkTheme.primary,
              backgroundColor: SlotSpyDarkTheme.surface,
              labelStyle: TextStyle(
                color: selected
                    ? SlotSpyDarkTheme.primary
                    : SlotSpyDarkTheme.textSecondary,
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        const Text(
          'Time Window (optional)',
          style: TextStyle(
              fontWeight: FontWeight.w600, color: SlotSpyDarkTheme.textPrimary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickTime(context, true),
                icon: const Icon(Icons.access_time,
                    color: SlotSpyDarkTheme.textSecondary),
                label: Text(
                  _earliestTime != null
                      ? _formatTime(_earliestTime!)
                      : 'Earliest time',
                  style:
                      const TextStyle(color: SlotSpyDarkTheme.textSecondary),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: SlotSpyDarkTheme.surfaceLight),
                  backgroundColor: SlotSpyDarkTheme.surface,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('to',
                  style: TextStyle(color: SlotSpyDarkTheme.textSecondary)),
            ),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickTime(context, false),
                icon: const Icon(Icons.access_time,
                    color: SlotSpyDarkTheme.textSecondary),
                label: Text(
                  _latestTime != null ? _formatTime(_latestTime!) : 'Latest time',
                  style:
                      const TextStyle(color: SlotSpyDarkTheme.textSecondary),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: SlotSpyDarkTheme.surfaceLight),
                  backgroundColor: SlotSpyDarkTheme.surface,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickTime(BuildContext context, bool isEarliest) async {
    final initial = isEarliest
        ? (_earliestTime ?? const TimeOfDay(hour: 6, minute: 0))
        : (_latestTime ?? const TimeOfDay(hour: 22, minute: 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        if (isEarliest) {
          _earliestTime = picked;
        } else {
          _latestTime = picked;
        }
        if (_currentStep == 2) _currentStep = 3;
      });
    }
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  Widget _buildReviewStep() {
    final watch = _buildWatch();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: SlotSpyDarkTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SlotSpyDarkTheme.surfaceLight),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Watch Summary',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: SlotSpyDarkTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _reviewRow('Gym', watch.gymName ?? 'Any gym'),
              _reviewRow(
                  'Sessions',
                  _watchAllSessions
                      ? 'All sessions at this gym'
                      : _selectedSessionPatterns.isEmpty
                          ? 'Any session'
                          : _selectedSessionPatterns.join(', ')),
              _reviewRow('Days', _selectedDays.isEmpty
                  ? 'Any day'
                  : _daysSummary(_selectedDays)),
              _reviewRow('Time', _getTimePrefsSummary()),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Notifications enabled',
              style: TextStyle(color: SlotSpyDarkTheme.textPrimary)),
          subtitle: const Text('Get notified when matching slots are found',
              style: TextStyle(color: SlotSpyDarkTheme.textSecondary)),
          value: _notificationsEnabled,
          onChanged: (v) => setState(() => _notificationsEnabled = v),
          activeColor: SlotSpyDarkTheme.primary,
        ),
      ],
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: SlotSpyDarkTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: SlotSpyDarkTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTimePrefsSummary() {
    if (_earliestTime == null && _latestTime == null) {
      return 'Any time';
    }
    final start =
        _earliestTime != null ? _formatTime(_earliestTime!) : '00:00';
    final end = _latestTime != null ? _formatTime(_latestTime!) : '23:59';
    return '$start - $end';
  }

  String _daysSummary(Set<int> days) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = days.toList()..sort();
    return sorted.map((d) => dayNames[d - 1]).join(', ');
  }

  Watch _buildWatch() {
    return Watch(
      id: widget.watchToEdit?.id,
      gymId: _selectedGym?.id,
      gymName: _selectedGym?.name,
      sessionPatterns:
          _watchAllSessions ? null : (_selectedSessionPatterns.isNotEmpty ? _selectedSessionPatterns.toList() : null),
      daysOfWeek: _selectedDays.isNotEmpty ? _selectedDays : null,
      earliestTime: _earliestTime,
      latestTime: _latestTime,
      enabled: widget.watchToEdit?.enabled ?? true,
      notificationsEnabled: _notificationsEnabled,
      createdAt: widget.watchToEdit?.createdAt,
    );
  }

  void _onContinue() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _saveWatch();
    }
  }

  void _onCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _saveWatch() async {
    final provider = context.read<WatchProvider>();
    final watch = _buildWatch();
    if (_isEditing) {
      await provider.updateWatch(watch);
    } else {
      await provider.addWatch(watch);
    }
    if (mounted) Navigator.pop(context);
  }
}

/// Isolated widget for the session-step content.
/// Owns its own Consumer<SlotProvider> so page notifications from the provider
/// only rebuild this subtree — not the parent Stepper.
/// Sessions are NEVER auto-fetched. User taps "Load sessions" to fetch.
class _SessionStepContent extends StatefulWidget {
  final Gym gym;
  final bool watchAllSessions;
  final Set<String> selectedSessionPatterns;
  final ValueChanged<bool?> onWatchAllSessionsChanged;
  final ValueChanged<String> onSessionPatternToggled;

  const _SessionStepContent({
    super.key,
    required this.gym,
    required this.watchAllSessions,
    required this.selectedSessionPatterns,
    required this.onWatchAllSessionsChanged,
    required this.onSessionPatternToggled,
  });

  @override
  State<_SessionStepContent> createState() => _SessionStepContentState();
}

class _SessionStepContentState extends State<_SessionStepContent> {
  List<SessionType> _sessionsAtGym(List<SessionType> allTypes) {
    final q = widget.gym.name.toLowerCase();
    return allTypes.where((st) => st.gym.name.toLowerCase() == q).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isStaticGym = widget.gym.provider == 'everyoneactive' ||
        widget.gym.provider == 'better';

    return Consumer<SlotProvider>(
      builder: (context, provider, _) {
        final sessions = _sessionsAtGym(provider.sessionTypes);
        final isLoading = provider.loadingSessionSeries;

        // Show spinner while fetching
        if (isLoading && sessions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const CircularProgressIndicator(
                    color: SlotSpyDarkTheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Loading sessions at ${widget.gym.name}...',
                  style: const TextStyle(
                      color: SlotSpyDarkTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        // No sessions at all — show load button
        if (sessions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.hourglass_empty,
                    color: SlotSpyDarkTheme.textSecondary, size: 40),
                const SizedBox(height: 12),
                Text(
                  isStaticGym
                      ? 'No cached sessions for ${widget.gym.name}'
                      : 'No sessions found at this gym.',
                  style: const TextStyle(color: SlotSpyDarkTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => provider.fetchSessionSeries(),
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: SlotSpyDarkTheme.primary,
                          ),
                        )
                      : const Icon(Icons.refresh,
                          color: SlotSpyDarkTheme.primary),
                  label: Text(
                    isLoading ? 'Loading...' : 'Load sessions',
                    style: const TextStyle(color: SlotSpyDarkTheme.primary),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: SlotSpyDarkTheme.primary),
                  ),
                ),
              ],
            ),
          );
        }

        // Sessions available — show list with refresh button
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: session count + refresh button
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${sessions.length} session${sessions.length == 1 ? '' : 's'} from last check',
                      style: const TextStyle(
                          color: SlotSpyDarkTheme.textSecondary, fontSize: 13),
                    ),
                  ),
                  if (isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: SlotSpyDarkTheme.primary,
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh,
                          color: SlotSpyDarkTheme.primary, size: 20),
                      onPressed: () => provider.fetchSessionSeries(),
                      tooltip: 'Refresh sessions',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
            CheckboxListTile(
              value: widget.watchAllSessions,
              onChanged: widget.onWatchAllSessionsChanged,
              title: const Text('Watch all sessions at this gym',
                  style: TextStyle(color: SlotSpyDarkTheme.textPrimary)),
              subtitle: Text(
                  '(${sessions.length} session${sessions.length == 1 ? '' : 's'})',
                  style: const TextStyle(color: SlotSpyDarkTheme.textSecondary)),
              activeColor: SlotSpyDarkTheme.primary,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            const Divider(color: SlotSpyDarkTheme.surfaceLight),
            const SizedBox(height: 8),
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: sessions.length,
                itemExtent: 72,
                itemBuilder: (context, index) {
                  final st = sessions[index];
                  final isSelected =
                      widget.selectedSessionPatterns.contains(st.name);
                  return Card(
                    elevation: 0,
                    color: isSelected
                        ? SlotSpyDarkTheme.primary.withValues(alpha: 0.15)
                        : SlotSpyDarkTheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isSelected
                          ? const BorderSide(color: SlotSpyDarkTheme.primary)
                          : BorderSide.none,
                    ),
                    child: ListTile(
                      title: Text(st.name,
                          style: const TextStyle(
                              color: SlotSpyDarkTheme.textPrimary)),
                      subtitle: Text(
                        '${st.activity}${st.price != null ? ' • £${st.price!.toStringAsFixed(2)}' : ''}',
                        style: const TextStyle(
                            color: SlotSpyDarkTheme.textSecondary)),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle,
                              color: SlotSpyDarkTheme.primary)
                          : null,
                      onTap: () => widget.onSessionPatternToggled(st.name),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

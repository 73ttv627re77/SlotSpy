import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/watch_provider.dart';
import '../models/watch.dart';
import '../models/gym.dart';
import '../models/session_type.dart';
import '../theme/slotspy_dark_theme.dart';

class AddWatchScreen extends StatefulWidget {
  final Watch? watchToEdit;

  const AddWatchScreen({super.key, this.watchToEdit});

  @override
  State<AddWatchScreen> createState() => _AddWatchScreenState();
}

class _AddWatchScreenState extends State<AddWatchScreen> {
  int _currentStep = 0;
  Gym? _selectedGym;
  SessionType? _selectedSessionType;
  String _sessionNamePattern = '';
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
      _sessionNamePattern = w.sessionNamePattern ?? '';
      _selectedDays = w.daysOfWeek ?? {};
      _earliestTime = w.earliestTime != null
          ? TimeOfDay(hour: w.earliestTime!.hour, minute: w.earliestTime!.minute)
          : null;
      _latestTime = w.latestTime != null
          ? TimeOfDay(hour: w.latestTime!.hour, minute: w.latestTime!.minute)
          : null;
      _notificationsEnabled = w.notificationsEnabled;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SlotProvider>().loadCachedSessionSeries();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SlotProvider>().loadCachedSessionSeries();
      });
    }
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
            title: const Text('Session Type',
                style: TextStyle(color: SlotSpyDarkTheme.textPrimary)),
            subtitle: Text(
              _sessionNamePattern.isNotEmpty ? _sessionNamePattern : 'Any session',
              style: const TextStyle(color: SlotSpyDarkTheme.textSecondary),
            ),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: _buildSessionTypeStep(),
          ),
          Step(
            title: const Text('Gym',
                style: TextStyle(color: SlotSpyDarkTheme.textPrimary)),
            subtitle: Text(
              _selectedGym?.name ?? 'Any gym',
              style: const TextStyle(color: SlotSpyDarkTheme.textSecondary),
            ),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: _buildGymStep(),
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

  Widget _buildSessionTypeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Search sessions (e.g. Badminton, Gym)',
            prefixIcon:
                const Icon(Icons.search, color: SlotSpyDarkTheme.textSecondary),
            filled: true,
            fillColor: SlotSpyDarkTheme.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(color: SlotSpyDarkTheme.textPrimary),
          onChanged: (v) => setState(() => _sessionNamePattern = v),
        ),
        const SizedBox(height: 16),
        Consumer<SlotProvider>(
          builder: (context, provider, _) {
            if (provider.loadingSessionSeries) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: SlotSpyDarkTheme.primary));
            }
            final types = provider.searchSessionTypes(_sessionNamePattern);
            if (types.isEmpty && provider.sessionTypes.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No session types loaded yet. You can continue without selecting one.',
                  style: TextStyle(color: SlotSpyDarkTheme.textSecondary),
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: types.length,
              itemBuilder: (context, index) {
                final st = types[index];
                final isSelected = _selectedSessionType?.id == st.id;
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
                        style:
                            const TextStyle(color: SlotSpyDarkTheme.textPrimary)),
                    subtitle: Text('${st.gym.name} • ${st.activity}',
                        style: const TextStyle(
                            color: SlotSpyDarkTheme.textSecondary)),
                    trailing: st.price != null
                        ? Text(
                            '£${st.price!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: SlotSpyDarkTheme.success,
                            ),
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedSessionType = isSelected ? null : st;
                        _selectedGym = st.gym;
                      });
                    },
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildGymStep() {
    return Consumer<SlotProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: const Text('Any gym',
                  style: TextStyle(color: SlotSpyDarkTheme.textPrimary)),
              leading: Radio<String?>(
                value: null,
                groupValue: _selectedGym?.id,
                activeColor: SlotSpyDarkTheme.primary,
                onChanged: (_) => setState(() => _selectedGym = null),
              ),
              onTap: () => setState(() => _selectedGym = null),
            ),
            const Divider(color: SlotSpyDarkTheme.surfaceLight),
            ...provider.gyms.map((gym) {
              final isSelected = _selectedGym?.id == gym.id;
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
                  subtitle: Text(gym.address,
                      style:
                          const TextStyle(color: SlotSpyDarkTheme.textSecondary)),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle,
                          color: SlotSpyDarkTheme.primary)
                      : null,
                  onTap: () => setState(() => _selectedGym = gym),
                ),
              );
            }),
          ],
        );
      },
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
              _reviewRow('Session', watch.sessionNamePattern ?? 'Any session'),
              _reviewRow('Gym', watch.gymName ?? 'Any gym'),
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
      sessionNamePattern:
          _sessionNamePattern.isNotEmpty ? _sessionNamePattern : null,
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

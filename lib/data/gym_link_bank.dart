// Booking link bank — maps gym facility IDs to direct booking URLs.
///
/// When a slot alert fires, we use this bank to construct the best possible
/// booking URL instead of falling back to a generic homepage.
///
/// iOS native WidgetKit setup steps (requires manual Xcode work):
/// 1. Open ios/Runner.xcworkspace in Xcode
/// 2. Add a WidgetKit target (File > New > Target > Widget Extension)
/// 3. Configure the App Group: "group.com.slotspy.app" (in both main app and widget targets)
/// 4. Create a SlotSpyWidget.swift that reads from the App Group SharedPreferences
/// 5. For full lock-screen widgets, enable the WidgetKit capability in the widget target
/// 6. Call HomeWidget.saveWidgetData() after each poll to update widget state

class GymLink {
  final String provider;
  final String facilityIdPattern;
  final String gymName;
  final String baseUrl;
  final String bookingPathTemplate;
  /// If true, slot.@id IS the direct booking URL (use it directly).
  /// If false, construct URL from baseUrl + bookingPathTemplate + facilityId.
  final bool useSlotIdDirectly;
  /// OpenActive session-series feed URL for this provider.
  final String? sessionFeedUrl;

  const GymLink({
    required this.provider,
    required this.facilityIdPattern,
    required this.gymName,
    required this.baseUrl,
    required this.bookingPathTemplate,
    this.useSlotIdDirectly = false,
    this.sessionFeedUrl,
  });

  /// Build the booking URL for a given slot.
  /// [slotId] is the slot's @id field.
  /// [facilityUseId] is the extracted facility use ID.
  String buildBookingUrl(String slotId, String facilityUseId) {
    if (useSlotIdDirectly) {
      return slotId;
    }
    // Replace {facilityId} in template with the actual ID
    final path = bookingPathTemplate.replaceAll('{facilityId}', facilityUseId);
    return '$baseUrl$path';
  }
}

/// Known gym booking link mappings.
///
/// Provider patterns:
/// - Everyone Active: slot.@id is already the direct booking URL
/// - Better (GLL): booking URL = https://better-admin.org.uk/booking?facility={facilityId}
///   where facilityId comes from the individual facility use @id
///   e.g. individual facility use id = "activity_recurrence_group:6349:individual_facility_use:12345"
///        booking URL = https://better-admin.org.uk/booking?facility=12345
class GymLinkBank {
  static const String providerEveryoneActive = 'everyoneactive';
  static const String providerBetter = 'better';

  /// All known gym links. Key = provider name.
  /// We look up by provider + facility ID prefix.
  static const Map<String, GymLink> _links = {
    providerBetter: GymLink(
      provider: providerBetter,
      facilityIdPattern: '*',
      gymName: 'Better (GLL)',
      baseUrl: 'https://better-admin.org.uk',
      bookingPathTemplate: '/booking?facility={facilityId}',
      useSlotIdDirectly: false,
      sessionFeedUrl: 'https://better-admin.org.uk/api/openactive/better/session-series',
    ),
  };

  /// Static map of Everyone Active base URLs (EA slots use @id directly).
  /// These are prefixes that indicate a slot @id IS the direct booking URL.
  static const Set<String> _everyoneActiveIdPrefixes = {
    'https://dev.myeveryoneactive.com/OpenActive/api/slots/',
    'https://www.myeveryoneactive.com/OpenActive/api/slots/',
    'https://staging.myeveryoneactive.com/OpenActive/api/slots/',
  };

  /// Look up a GymLink by provider name.
  static GymLink? lookupByProvider(String provider) {
    return _links[provider.toLowerCase()];
  }

  /// Check if a slot @id belongs to Everyone Active (and is thus a direct URL).
  static bool isEveryoneActiveSlotId(String slotId) {
    for (final prefix in _everyoneActiveIdPrefixes) {
      if (slotId.startsWith(prefix)) return true;
    }
    return slotId.contains('myeveryoneactive.com') ||
        slotId.contains('everyoneactive.com');
  }

  /// Extract the facility ID from a Better facility use URL.
  /// e.g. "https://better-admin.org.uk/api/openactive/better/facility-uses/activity_recurrence_group:6349/individual-facility-uses/12345"
  ///   → returns "12345"
  static String? extractBetterFacilityId(String facilityUseUrl) {
    // Match the trailing ID after "individual-facility-uses/"
    final match = RegExp(r'individual-facility-uses/([^\s/]+)').firstMatch(facilityUseUrl);
    if (match != null) return match.group(1);

    // Fallback: look for any numeric suffix
    final fallbackMatch = RegExp(r'/(\d+)$').firstMatch(facilityUseUrl);
    return fallbackMatch?.group(1);
  }

  /// Build the best booking URL for a slot.
  /// [slotId] — the slot's @id field
  /// [facilityUseUrl] — the facilityUse URL from the slot data
  /// [fallbackUrl] — session series url field (last resort)
  static String buildBestBookingUrl({
    required String slotId,
    required String facilityUseUrl,
    String? fallbackUrl,
  }) {
    // 1. Everyone Active: slot.@id IS the direct URL
    if (isEveryoneActiveSlotId(slotId)) {
      return slotId;
    }

    // 2. Check if it's a Better slot
    if (facilityUseUrl.contains('better-admin.org.uk') ||
        facilityUseUrl.contains('better.org.uk')) {
      final facilityId = extractBetterFacilityId(facilityUseUrl);
      if (facilityId != null) {
        return 'https://better-admin.org.uk/booking?facility=$facilityId';
      }
    }

    // 3. Look up by provider in link bank
    for (final link in _links.values) {
      if (facilityUseUrl.contains(link.provider)) {
        return link.buildBookingUrl(slotId, facilityUseUrl);
      }
    }

    // 4. Fallback to session series URL
    if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
      return fallbackUrl;
    }

    // 5. Last resort: try the slot @id as-is
    return slotId;
  }
}

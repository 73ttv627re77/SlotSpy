class Gym {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lon;
  /// Provider name: 'everyoneactive' or 'better'.
  final String? provider;
  /// OpenActive session-series feed URL for this provider.
  final String? sessionFeedUrl;

  Gym({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lon,
    this.provider,
    this.sessionFeedUrl,
  });

  factory Gym.fromSessionSeries(Map<String, dynamic> data) {
    final location = data['location'] ?? {};
    final address = location['address'] ?? {};
    final geo = location['geo'] ?? {};
    return Gym(
      id: data['@id'] ?? '',
      name: location['name'] ?? 'Unknown Gym',
      address: _formatAddress(address),
      lat: (geo['latitude'] ?? 0.0).toDouble(),
      lon: (geo['longitude'] ?? 0.0).toDouble(),
      provider: null,
      sessionFeedUrl: null,
    );
  }

  /// Create a Gym from a static VenueDatabase entry.
  factory Gym.fromVenueDbEntry({
    required String id,
    required String name,
    required String address,
    required double lat,
    required double lon,
    required String? provider,
    required String? sessionFeedUrl,
  }) {
    return Gym(
      id: id,
      name: name,
      address: address,
      lat: lat,
      lon: lon,
      provider: provider,
      sessionFeedUrl: sessionFeedUrl,
    );
  }

  static String _formatAddress(Map<String, dynamic> address) {
    final parts = <String>[
      address['streetAddress'] ?? '',
      address['addressLocality'] ?? '',
      address['postalCode'] ?? '',
    ].where((s) => s.isNotEmpty).toList();
    return parts.join(', ');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Gym && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

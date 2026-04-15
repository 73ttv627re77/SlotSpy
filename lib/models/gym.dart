class Gym {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lon;

  Gym({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lon,
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

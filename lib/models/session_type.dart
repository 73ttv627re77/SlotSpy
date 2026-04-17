import 'gym.dart';

class SessionType {
  final String id;
  final String name;
  final String activity;
  final Gym gym;
  final String? description;
  final double? price;
  final String? url;

  SessionType({
    required this.id,
    required this.name,
    required this.activity,
    required this.gym,
    this.description,
    this.price,
    this.url,
  });

  factory SessionType.fromBackend(Map<String, dynamic> data) {
    final gymData = data['gym'] as Map<String, dynamic>?;
    final gym = gymData != null ? Gym.fromBackend(gymData) : Gym(id: '', name: 'Unknown Gym', address: '', lat: 0.0, lon: 0.0);
    return SessionType(
      id: data['id']?.toString() ?? data['@id'] ?? '',
      name: data['name']?.toString() ?? 'Unknown Session',
      activity: data['activity']?.toString() ?? 'Unknown',
      gym: gym,
      description: data['description']?.toString(),
      price: (data['price'] as num?)?.toDouble(),
      url: data['url']?.toString(),
    );
  }

  factory SessionType.fromSessionSeries(Map<String, dynamic> data, Gym gym) {
    final superEvent = data['superEvent'] ?? {};
    final activityArr = superEvent['activity'] ?? [];
    final activity = activityArr.isNotEmpty
        ? (activityArr[0]['prefLabel'] ?? 'Unknown') as String
        : 'Unknown';
    final offers = data['offers'] as List? ?? [];
    double? price;
    if (offers.isNotEmpty) {
      price = (offers[0]['price'] ?? 0.0).toDouble();
    }
    return SessionType(
      id: data['@id'] ?? '',
      name: data['name'] ?? 'Unknown Session',
      activity: activity,
      gym: gym,
      description: data['description'] as String?,
      price: price,
      url: data['url'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SessionType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

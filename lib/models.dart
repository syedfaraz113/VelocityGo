import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String username;
  final String email;
  final String role; // 'rider' or 'driver'
  final double rating;
  final int totalRides;

  UserModel({
    required this.uid,
    required this.username,
    required this.email,
    required this.role,
    this.rating = 5.0,
    this.totalRides = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'email': email,
      'role': role,
      'rating': rating,
      'totalRides': totalRides,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'rider',
      rating: (map['rating'] ?? 5.0).toDouble(),
      totalRides: map['totalRides'] ?? 0,
    );
  }
}

class DriverModel {
  final String uid;
  final String username;
  final double latitude;
  final double longitude;
  final bool available;
  final int locationIndex;
  final double rating;
  final int totalTrips;
  final double earnings;

  DriverModel({
    required this.uid,
    required this.username,
    required this.latitude,
    required this.longitude,
    this.available = true,
    this.locationIndex = 0,
    this.rating = 5.0,
    this.totalTrips = 0,
    this.earnings = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'latitude': latitude,
      'longitude': longitude,
      'available': available,
      'locationIndex': locationIndex,
      'rating': rating,
      'totalTrips': totalTrips,
      'earnings': earnings,
    };
  }

  factory DriverModel.fromMap(Map<String, dynamic> map) {
    return DriverModel(
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      available: map['available'] ?? true,
      locationIndex: map['locationIndex'] ?? 0,
      rating: (map['rating'] ?? 5.0).toDouble(),
      totalTrips: map['totalTrips'] ?? 0,
      earnings: (map['earnings'] ?? 0.0).toDouble(),
    );
  }
}


class LocationModel {
  final String name;
  final double latitude;
  final double longitude;
  final List<Edge> edges;

  LocationModel({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.edges = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'edges': edges.map((e) => e.toMap()).toList(),
    };
  }

  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      name: map['name'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      edges: (map['edges'] as List?)
          ?.map((e) => Edge.fromMap(e as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }
}

class Edge {
  final int targetIndex;
  final double distance;

  Edge(this.targetIndex, this.distance);

  Map<String, dynamic> toMap() {
    return {
      'targetIndex': targetIndex,
      'distance': distance,
    };
  }

  factory Edge.fromMap(Map<String, dynamic> map) {
    return Edge(
      map['targetIndex'] ?? 0,
      (map['distance'] ?? 0.0).toDouble(),
    );
  }
}

class Location {
  final String name;
  final double latitude;
  final double longitude;

  Location({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory Location.fromMap(Map<String, dynamic> map) {
    return Location(
      name: map['name'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
    );
  }
}

class RideRequest {
  final String id;
  final String riderUid;
  final String riderName;
  final int pickupLocationIndex;
  final int dropLocationIndex;
  final double fare;
  final DateTime timestamp;
  final String status; // 'pending', 'accepted', 'in_progress', 'completed', 'cancelled'
  final String? driverUid;
  final String? driverName;

  RideRequest({
    required this.id,
    required this.riderUid,
    required this.riderName,
    required this.pickupLocationIndex,
    required this.dropLocationIndex,
    required this.fare,
    required this.timestamp,
    this.status = 'pending',
    this.driverUid,
    this.driverName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'riderUid': riderUid,
      'riderName': riderName,
      'pickupLocationIndex': pickupLocationIndex,
      'dropLocationIndex': dropLocationIndex,
      'fare': fare,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status,
      'driverUid': driverUid,
      'driverName': driverName,
    };
  }

  factory RideRequest.fromMap(Map<String, dynamic> map) {
    return RideRequest(
      id: map['id'] ?? '',
      riderUid: map['riderUid'] ?? '',
      riderName: map['riderName'] ?? '',
      pickupLocationIndex: map['pickupLocationIndex'] ?? 0,
      dropLocationIndex: map['dropLocationIndex'] ?? 0,
      fare: (map['fare'] ?? 0.0).toDouble(),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      status: map['status'] ?? 'pending',
      driverUid: map['driverUid'],
      driverName: map['driverName'],
    );
  }

  RideRequest copyWith({
    String? status,
    String? driverUid,
    String? driverName,
  }) {
    return RideRequest(
      id: id,
      riderUid: riderUid,
      riderName: riderName,
      pickupLocationIndex: pickupLocationIndex,
      dropLocationIndex: dropLocationIndex,
      fare: fare,
      timestamp: timestamp,
      status: status ?? this.status,
      driverUid: driverUid ?? this.driverUid,
      driverName: driverName ?? this.driverName,
    );
  }
}
class IslamabadLocation {
  final String name;
  final double latitude;
  final double longitude;

  IslamabadLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
  }
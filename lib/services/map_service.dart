import 'dart:collection';
import 'dart:math';
import '../models.dart';

class IslamabadMapService {
  static final IslamabadMapService _instance = IslamabadMapService._internal();
  factory IslamabadMapService() => _instance;
  IslamabadMapService._internal();

  late List<LocationModel> locations;

  void initializeMap() {
    locations = [
      LocationModel(
        name: "Blue Area",
        latitude: 33.7184,
        longitude: 73.0594,
        edges: [
          Edge(1, 120),
          Edge(2, 110),
          Edge(5, 80),
          Edge(10, 30),
        ],
      ),
      LocationModel(
        name: "F-6 Markaz",
        latitude: 33.7151,
        longitude: 73.0551,
        edges: [
          Edge(0, 120),
          Edge(2, 100),
          Edge(4, 80),
        ],
      ),
      LocationModel(
        name: "F-7 Markaz",
        latitude: 33.7100,
        longitude: 73.0551,
        edges: [
          Edge(0, 110),
          Edge(1, 100),
          Edge(3, 100),
          Edge(6, 120),
        ],
      ),
      LocationModel(
        name: "F-8 Markaz",
        latitude: 33.7020,
        longitude: 73.0551,
        edges: [
          Edge(2, 100),
          Edge(7, 150),
          Edge(9, 120),
        ],
      ),
      LocationModel(
        name: "Jinnah Super",
        latitude: 33.7160,
        longitude: 73.0650,
        edges: [
          Edge(1, 80),
          Edge(5, 100),
        ],
      ),
      LocationModel(
        name: "Aabpara Market",
        latitude: 33.7250,
        longitude: 73.0550,
        edges: [
          Edge(0, 80),
          Edge(4, 100),
          Edge(11, 90),
        ],
      ),
      LocationModel(
        name: "G-9 Markaz",
        latitude: 33.6944,
        longitude: 73.0444,
        edges: [
          Edge(2, 120),
          Edge(7, 100),
        ],
      ),
      LocationModel(
        name: "G-10 Markaz",
        latitude: 33.6844,
        longitude: 73.0444,
        edges: [
          Edge(3, 150),
          Edge(6, 100),
          Edge(8, 150),
        ],
      ),
      LocationModel(
        name: "Bahria Town",
        latitude: 33.5651,
        longitude: 73.0169,
        edges: [
          Edge(7, 150),
          Edge(9, 100),
        ],
      ),
      LocationModel(
        name: "DHA Phase 2",
        latitude: 33.5975,
        longitude: 73.1170,
        edges: [
          Edge(3, 120),
          Edge(8, 100),
          Edge(10, 250),
        ],
      ),
      LocationModel(
        name: "Centaurus Mall",
        latitude: 33.7078,
        longitude: 73.0551,
        edges: [
          Edge(0, 30),
          Edge(9, 250),
        ],
      ),
      LocationModel(
        name: "Faisal Mosque",
        latitude: 33.7297,
        longitude: 73.0372,
        edges: [
          Edge(5, 90),
          Edge(0, 120),
        ],
      ),
    ];
  }

  // Dijkstra's algorithm for shortest path
  List<int> dijkstra(int start, int end) {
    int n = locations.length;
    List<double> dist = List.filled(n, double.infinity);
    List<int> prev = List.filled(n, -1);
    List<bool> visited = List.filled(n, false);

    dist[start] = 0;
    var pq = PriorityQueue<_Node>((a, b) => a.distance.compareTo(b.distance));
    pq.add(_Node(start, 0));

    while (pq.isNotEmpty) {
      var current = pq.removeFirst();
      int u = current.index;

      if (visited[u]) continue;
      visited[u] = true;

      for (var edge in locations[u].edges) {
        int v = edge.targetIndex;
        double weight = edge.distance;

        if (dist[u] + weight < dist[v]) {
          dist[v] = dist[u] + weight;
          prev[v] = u;
          pq.add(_Node(v, dist[v]));
        }
      }
    }

    List<int> path = [];
    for (int at = end; at != -1; at = prev[at]) {
      path.add(at);
    }
    return path.reversed.toList();
  }

  // Calculate total distance along path
  double calculateDistance(int start, int end) {
    List<int> path = dijkstra(start, end);
    double total = 0;

    for (int i = 0; i < path.length - 1; i++) {
      for (var edge in locations[path[i]].edges) {
        if (edge.targetIndex == path[i + 1]) {
          total += edge.distance;
          break;
        }
      }
    }
    return total;
  }

  // Calculate fare based on distance
  double calculateFare(double distance) {
    return distance * 0.5 + 50;
  }

  // Find nearest location to given coordinates
  int findNearestLocation(double lat, double lon) {
    int nearestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < locations.length; i++) {
      double distance = _calculateHaversineDistance(
        lat,
        lon,
        locations[i].latitude,
        locations[i].longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = i;
      }
    }

    return nearestIndex;
  }

  // Calculate distance between two coordinates using Haversine formula
  double _calculateHaversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000; // Earth's radius in meters
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }
}

class _Node {
  final int index;
  final double distance;
  _Node(this.index, this.distance);
}

// Simple priority queue implementation
class PriorityQueue<T> {
  final List<T> _items = [];
  final Comparator<T> _comparator;

  PriorityQueue(this._comparator);

  void add(T item) {
    _items.add(item);
    _items.sort(_comparator);
  }

  T removeFirst() {
    return _items.removeAt(0);
  }

  bool get isNotEmpty => _items.isNotEmpty;
  bool get isEmpty => _items.isEmpty;
}
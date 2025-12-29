import 'package:flutter/material.dart';
import 'dart:async';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import '../models.dart';
import '../services/map_service.dart';
import '../services/auth_service.dart';
import 'rider_dashboard.dart';

class TrackingScreen extends StatefulWidget {
  final UserModel user;
  final RideRequest ride;
  final DriverModel driver;

  const TrackingScreen({
    Key? key,
    required this.user,
    required this.ride,
    required this.driver,
  }) : super(key: key);

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with SingleTickerProviderStateMixin {
  final IslamabadMapService _mapService = IslamabadMapService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  MapboxMap? _mapboxMap;
  late AnimationController _progressController;
  Timer? _progressTimer;
  Timer? _carUpdateTimer;
  double _progress = 0.0;
  Position? _currentCarPosition;
  List<Position> _routeCoordinates = [];
  bool _routeLoading = true;
  double _routeDistance = 0.0;
  double _routeDuration = 0.0;
  double _currentBearing = 0.0;

  static const String MAPBOX_ACCESS_TOKEN = 'pk.eyJ1IjoiZmFyYXo4NTAwIiwiYSI6ImNtam8xNXFzNjBqbWUzY3NkMjdlOWEweWcifQ.mR5-S1dI5CfzldAVjJ8jgg';

  PointAnnotationManager? _carMarkerManager;
  PointAnnotation? _carAnnotation;
  CircleAnnotationManager? _carCircleManager;
  CircleAnnotation? _carCircle;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    try {
      final pickupLoc = _mapService.locations[widget.ride.pickupLocationIndex];
      final dropLoc = _mapService.locations[widget.ride.dropLocationIndex];

      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
            '${pickupLoc.longitude},${pickupLoc.latitude};'
            '${dropLoc.longitude},${dropLoc.latitude}'
            '?geometries=geojson&access_token=$MAPBOX_ACCESS_TOKEN',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List;

          setState(() {
            _routeCoordinates = coordinates
                .map((coord) => Position(
              (coord[0] as num).toDouble(),
              (coord[1] as num).toDouble(),
            ))
                .toList();

            _routeDistance = (route['distance'] as num).toDouble();
            _routeDuration = (route['duration'] as num).toDouble();
            _routeLoading = false;
          });

          _startRideSimulation();
        }
      } else {
        _useFallbackRoute();
      }
    } catch (e) {
      print('Error fetching route: $e');
      _useFallbackRoute();
    }
  }

  void _useFallbackRoute() {
    final pickupLoc = _mapService.locations[widget.ride.pickupLocationIndex];
    final dropLoc = _mapService.locations[widget.ride.dropLocationIndex];

    setState(() {
      _routeCoordinates = [
        Position(pickupLoc.longitude, pickupLoc.latitude),
        Position(dropLoc.longitude, dropLoc.latitude),
      ];
      _routeDistance = _mapService.calculateDistance(
        widget.ride.pickupLocationIndex,
        widget.ride.dropLocationIndex,
      );
      _routeDuration = 600;
      _routeLoading = false;
    });

    _startRideSimulation();
  }

  void _startRideSimulation() {
    if (_routeCoordinates.isEmpty) return;

    _currentCarPosition = _routeCoordinates.first;

    _progressTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) { // Changed from 100ms to 200ms
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _progress += 0.006; // Doubled from 0.003 to maintain same speed
        if (_progress >= 1.0) {
          _progress = 1.0;
          timer.cancel();
        }
        _updateCarPosition();
      });
    });
  }

  void _updateCarPosition() {
    if (_routeCoordinates.isEmpty || _progress >= 1.0) return;

    final totalPoints = _routeCoordinates.length;
    final currentIndex = (_progress * (totalPoints - 1)).floor();
    final nextIndex = (currentIndex + 1).clamp(0, totalPoints - 1).toInt();

    if (currentIndex >= totalPoints - 1) {
      _currentCarPosition = _routeCoordinates.last;
      _updateCarMarker();
      return;
    }

    final segmentProgress = (_progress * (totalPoints - 1)) - currentIndex;
    final current = _routeCoordinates[currentIndex];
    final next = _routeCoordinates[nextIndex];

    final lat = current.lat + (next.lat - current.lat) * segmentProgress;
    final lon = current.lng + (next.lng - current.lng) * segmentProgress;

    _currentCarPosition = Position(lon, lat);
    _currentBearing = _calculateBearing(current, next);

    _updateCarMarker();
  }

  double _calculateBearing(Position from, Position to) {
    final lat1 = from.lat * (math.pi / 180.0);
    final lat2 = to.lat * (math.pi / 180.0);
    final dLon = (to.lng - from.lng) * (math.pi / 180.0);

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    return math.atan2(y, x) * (180.0 / math.pi);
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    if (!_routeLoading) {
      await _setupMap();
    }
  }

  Future<void> _setupMap() async {
    if (_mapboxMap == null) return;
    await _drawRoute();
    await _addMarkers();
    await _addCarMarker();
    _fitBounds();
  }


  Future<void> _fitBounds() async {
    if (_routeCoordinates.isEmpty || _mapboxMap == null) return;

    // Calculate bounds from route coordinates
    double minLat = _routeCoordinates.first.lat.toDouble();
    double maxLat = _routeCoordinates.first.lat.toDouble();
    double minLng = _routeCoordinates.first.lng.toDouble();
    double maxLng = _routeCoordinates.first.lng.toDouble();

    for (var coord in _routeCoordinates) {
      final lat = coord.lat.toDouble();
      final lng = coord.lng.toDouble();

      minLat = math.min(minLat, lat).toDouble();
      maxLat = math.max(maxLat, lat).toDouble();
      minLng = math.min(minLng, lng).toDouble();
      maxLng = math.max(maxLng, lng).toDouble();
    }

    final bounds = CoordinateBounds(
      southwest: Point(coordinates: Position(minLng, minLat)),
      northeast: Point(coordinates: Position(maxLng, maxLat)),
      infiniteBounds: false,
    );

    await _mapboxMap!.setCamera(
      CameraOptions(
        center: Point(
          coordinates: Position(
            (minLng + maxLng) / 2,
            (minLat + maxLat) / 2,
          ),
        ),
        zoom: 13.0,
      ),
    );
  }

  Future<void> _drawRoute() async {
    if (_routeCoordinates.isEmpty || _mapboxMap == null) return;

    final polylineManager =
    await _mapboxMap!.annotations.createPolylineAnnotationManager();

    await polylineManager.create(
      PolylineAnnotationOptions(
        geometry: LineString(coordinates: _routeCoordinates),
        lineColor: const Color(0xFF00E5FF).value,
        lineWidth: 5.0,
        lineOpacity: 0.7,
      ),
    );
  }

  Future<void> _addMarkers() async {
    if (_mapboxMap == null) return;

    final pointManager =
    await _mapboxMap!.annotations.createPointAnnotationManager();

    final pickupLoc = _mapService.locations[widget.ride.pickupLocationIndex];
    await pointManager.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(pickupLoc.longitude, pickupLoc.latitude),
        ),
        iconSize: 1.5,
        iconColor: const Color(0xFF00E676).value,
      ),
    );

    final dropLoc = _mapService.locations[widget.ride.dropLocationIndex];
    await pointManager.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(dropLoc.longitude, dropLoc.latitude),
        ),
        iconSize: 1.5,
        iconColor: const Color(0xFFFF1744).value,
      ),
    );
  }

  Future<void> _addCarMarker() async {
    if (_mapboxMap == null || _currentCarPosition == null) return;

    // Add a circle for visibility
    _carCircleManager = await _mapboxMap!.annotations.createCircleAnnotationManager();
    _carCircle = await _carCircleManager!.create(
      CircleAnnotationOptions(
        geometry: Point(coordinates: _currentCarPosition!),
        circleRadius: 12.0,
        circleColor: const Color(0xFFFFD700).value,
        circleStrokeWidth: 2.0,
        circleStrokeColor: Colors.white.value,
      ),
    );

    // Add a point annotation on top
    _carMarkerManager = await _mapboxMap!.annotations.createPointAnnotationManager();
    _carAnnotation = await _carMarkerManager!.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: _currentCarPosition!),
        iconSize: 2.5,
        iconColor: Colors.black.value,
      ),
    );
  }

  Future<void> _updateCarMarker() async {
    if (_carCircleManager == null || _currentCarPosition == null) return;

    try {
      if (_carCircle != null) {
        await _carCircleManager!.delete(_carCircle!);
      }

      _carCircle = await _carCircleManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: _currentCarPosition!),
          circleRadius: 15.0,
          circleColor: const Color(0xFF3AB6A7).value,
          circleStrokeWidth: 3.0,
          circleStrokeColor: Colors.white.value,
        ),
      );
    } catch (e) {
      print('Error updating car marker: $e');
    }
  }

  Future<void> _completeRide() async {
    try {
      await _firestore.collection('rides').doc(widget.ride.id).update({
        'status': 'completed',
      });

      await _firestore.collection('drivers').doc(widget.driver.uid).update({
        'available': true,
        'totalTrips': FieldValue.increment(1),
        'earnings': FieldValue.increment(widget.ride.fare),
      });

      await _authService.incrementTotalRides(widget.user.uid);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Ride completed! Fare: Rs. ${widget.ride.fare.toStringAsFixed(0)}'),
          backgroundColor: const Color(0xFF00E676),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => RiderDashboard(user: widget.user),
        ),
            (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFFF1744),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _cancelRide() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cancel Ride',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to cancel this ride?',
          style: TextStyle(color: Color(0xFFB0B0C0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No', style: TextStyle(color: Color(0xFF00E5FF))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes', style: TextStyle(color: Color(0xFFFF1744))),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore.collection('rides').doc(widget.ride.id).update({
        'status': 'cancelled',
      });

      await _firestore.collection('drivers').doc(widget.driver.uid).update({
        'available': true,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ride cancelled'),
          backgroundColor: const Color(0xFFFF9100),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => RiderDashboard(user: widget.user),
        ),
            (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFFF1744),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _progressTimer?.cancel();
    _carUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final distance = _routeDistance > 0
        ? _routeDistance
        : _mapService.calculateDistance(
      widget.ride.pickupLocationIndex,
      widget.ride.dropLocationIndex,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: _routeLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(
              color: Color(0xFF00E5FF),
            ),
            SizedBox(height: 20),
            Text(
              'Calculating route...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      )
          : Stack(
        children: [
          // Map
          MapWidget(
            key: const ValueKey("trackingMap"),
            styleUri: MapboxStyles.DARK,
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(73.0479, 33.6844)),
              zoom: 12.0,
            ),
            onMapCreated: _onMapCreated,
          ),

          // Header with progress
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 50, bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0A0A0F).withOpacity(0.95),
                    const Color(0xFF0A0A0F).withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Ride in Progress',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF00E5FF).withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          'ETA: ${((1 - _progress) * (_routeDuration / 60)).toStringAsFixed(0)} min',
                          style: const TextStyle(
                            color: Color(0xFF00E5FF),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Stack(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E2E),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Container(
                        height: 6,
                        width: MediaQuery.of(context).size.width * _progress * 0.88,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00E5FF), Color(0xFF00B8D4)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withOpacity(0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(_progress * 100).toStringAsFixed(0)}% Complete',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Driver Info and Actions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF0A0A0F),
                    const Color(0xFF0A0A0F).withOpacity(0.95),
                    const Color(0xFF0A0A0F).withOpacity(0.7),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 0.8, 1.0],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Driver Info Card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1E1E2E).withOpacity(0.95),
                          const Color(0xFF2A2A40).withOpacity(0.9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00E5FF), Color(0xFF00B8D4)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withOpacity(0.4),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.driver.username,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Color(0xFFFFD700), size: 16),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${widget.driver.rating.toStringAsFixed(1)}',
                                    style: const TextStyle(
                                      color: Color(0xFFFFD700),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '${widget.driver.totalTrips} trips',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Rs. ${widget.ride.fare.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00E676),
                              ),
                            ),
                            Text(
                              '${(distance / 1000).toStringAsFixed(1)} km',
                              style: const TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 30),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFFF1744).withOpacity(0.8),
                                  const Color(0xFFD50000).withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF1744).withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _cancelRide,
                              icon: const Icon(Icons.cancel_outlined, size: 20),
                              label: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: _progress >= 0.9
                                  ? const LinearGradient(
                                colors: [Color(0xFF00E676), Color(0xFF00C853)],
                              )
                                  : LinearGradient(
                                colors: [
                                  const Color(0xFF424242).withOpacity(0.5),
                                  const Color(0xFF303030).withOpacity(0.5),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: _progress >= 0.9
                                  ? [
                                BoxShadow(
                                  color: const Color(0xFF00E676).withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ]
                                  : [],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _progress >= 0.9 ? _completeRide : null,
                              icon: const Icon(Icons.check_circle_outline, size: 20),
                              label: const Text(
                                'Complete',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.transparent,
                                disabledForegroundColor: Colors.white38,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
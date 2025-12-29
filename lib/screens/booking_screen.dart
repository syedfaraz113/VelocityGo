import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models.dart';
import '../services/map_service.dart';
import '../screens/tracking_screen.dart';
import 'dart:async';

class BookingScreen extends StatefulWidget {
  final UserModel user;

  const BookingScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> with SingleTickerProviderStateMixin {
  final IslamabadMapService _mapService = IslamabadMapService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String MAPBOX_ACCESS_TOKEN = 'pk.eyJ1IjoiZmFyYXo4NTAwIiwiYSI6ImNtam8xNXFzNjBqbWUzY3NkMjdlOWEweWcifQ.mR5-S1dI5CfzldAVjJ8jgg';

  MapboxMap? _mapboxMap;
  int? _selectedPickup;
  int? _selectedDrop;
  bool _isLoading = false;
  List<DriverModel> _availableDrivers = [];
  Position? _currentMapCenter;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;

  List<PointAnnotation> _locationAnnotations = [];
  List<PointAnnotation> _driverAnnotations = [];
  PolylineAnnotation? _routeAnnotation;

  double _routeDistance = 0.0;
  double _routeDuration = 0.0;
  String _routeDurationText = '';

  List<Position> _fullRoute = [];

  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropController = TextEditingController();
  final FocusNode _pickupFocusNode = FocusNode();
  final FocusNode _dropFocusNode = FocusNode();

  bool _showPickupSuggestions = false;
  bool _showDropSuggestions = false;
  List<LocationWithDistance> _filteredLocations = [];

  bool _isSelectingOnMap = false;
  String _mapSelectionMode = '';
  bool _showBottomSheet = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableDrivers();
    _currentMapCenter = Position(73.0479, 33.6844);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _setupFocusListeners();
  }

  void _setupFocusListeners() {
    _pickupFocusNode.addListener(() {
      if (_pickupFocusNode.hasFocus) {
        _filterLocationsByProximity(_pickupController.text);
        setState(() {
          _showPickupSuggestions = true;
          _showDropSuggestions = false;
        });
      }
    });

    _dropFocusNode.addListener(() {
      if (_dropFocusNode.hasFocus) {
        _filterLocationsByProximity(_dropController.text);
        setState(() {
          _showDropSuggestions = true;
          _showPickupSuggestions = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pickupController.dispose();
    _dropController.dispose();
    _pickupFocusNode.dispose();
    _dropFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableDrivers() async {
    try {
      final snapshot = await _firestore
          .collection('drivers')
          .where('available', isEqualTo: true)
          .get();

      if (mounted) {
        setState(() {
          _availableDrivers = snapshot.docs
              .map((doc) {
            try {
              final data = doc.data();
              data['uid'] = doc.id;
              return DriverModel.fromMap(data);
            } catch (e) {
              print('Error parsing driver ${doc.id}: $e');
              return null;
            }
          })
              .whereType<DriverModel>()
              .toList();
        });

        print('Loaded ${_availableDrivers.length} available drivers');
      }
    } catch (e) {
      print('Error loading drivers: $e');
      if (mounted) {
        _showSnackbar('Failed to load drivers: $e', const Color(0xFFFF1744));
      }
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      await _setupMap();
    }
  }

  Future<void> _setupMap() async {
    if (_mapboxMap == null) return;

    try {
      await _mapboxMap!.setCamera(
        CameraOptions(
          center: Point(coordinates: Position(73.0479, 33.6844)),
          zoom: 12.0,
        ),
      );

      _pointAnnotationManager ??= await _mapboxMap!.annotations.createPointAnnotationManager();
      _polylineAnnotationManager ??= await _mapboxMap!.annotations.createPolylineAnnotationManager();

      await _addDriverMarkers();

    } catch (e) {
      print('Error setting up map: $e');
    }
  }

  Future<void> _addDriverMarkers() async {
    try {
      if (_pointAnnotationManager == null) return;

      for (var annotation in _driverAnnotations) {
        await _pointAnnotationManager!.delete(annotation);
      }
      _driverAnnotations.clear();

      for (var driver in _availableDrivers) {
        final options = PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(driver.longitude, driver.latitude),
          ),
          iconSize: 0.7,
          iconColor: Colors.black.value,
          iconAnchor: IconAnchor.CENTER,
        );

        final annotation = await _pointAnnotationManager!.create(options);
        _driverAnnotations.add(annotation);
      }

    } catch (e) {
      print('Error adding driver markers: $e');
    }
  }

  Future<void> _addLocationMarkers() async {
    try {
      if (_pointAnnotationManager == null) return;

      for (var annotation in _locationAnnotations) {
        await _pointAnnotationManager!.delete(annotation);
      }
      _locationAnnotations.clear();

      if (_selectedPickup != null) {
        final loc = _mapService.locations[_selectedPickup!];
        final options = PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(loc.longitude, loc.latitude),
          ),
          iconSize: 1.2,
          iconColor: const Color(0xFF00E676).value,
          iconAnchor: IconAnchor.BOTTOM,
        );
        final annotation = await _pointAnnotationManager!.create(options);
        _locationAnnotations.add(annotation);
      }

      if (_selectedDrop != null) {
        final loc = _mapService.locations[_selectedDrop!];
        final options = PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(loc.longitude, loc.latitude),
          ),
          iconSize: 1.2,
          iconColor: const Color(0xFFFF1744).value,
          iconAnchor: IconAnchor.BOTTOM,
        );
        final annotation = await _pointAnnotationManager!.create(options);
        _locationAnnotations.add(annotation);
      }

    } catch (e) {
      print('Error adding location markers: $e');
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a)) * 1000;
  }

  void _filterLocationsByProximity(String query) {
    final centerLat = _currentMapCenter?.lat.toDouble() ?? 33.6844;
    final centerLon = _currentMapCenter?.lng.toDouble() ?? 73.0479;

    List<LocationWithDistance> locationsWithDistance = [];

    for (int i = 0; i < _mapService.locations.length; i++) {
      final loc = _mapService.locations[i];

      if ((_showPickupSuggestions && i == _selectedPickup) ||
          (_showDropSuggestions && i == _selectedDrop)) continue;

      if (query.isNotEmpty &&
          !loc.name.toLowerCase().contains(query.toLowerCase())) {
        continue;
      }

      final distance = _calculateDistance(
        centerLat,
        centerLon,
        loc.latitude,
        loc.longitude,
      );

      locationsWithDistance.add(LocationWithDistance(
        location: loc,
        index: i,
        distance: distance,
      ));
    }

    locationsWithDistance.sort((a, b) => a.distance.compareTo(b.distance));

    setState(() {
      _filteredLocations = locationsWithDistance.take(8).toList();
    });
  }

  void _selectPickupLocation(int index) {
    setState(() {
      _selectedPickup = index;
      _pickupController.text = _mapService.locations[index].name;
      _showPickupSuggestions = false;
      _isSelectingOnMap = false;
      _mapSelectionMode = '';
    });
    _pickupFocusNode.unfocus();
    _updateMapAfterSelection();
  }

  void _selectDropLocation(int index) {
    setState(() {
      _selectedDrop = index;
      _dropController.text = _mapService.locations[index].name;
      _showDropSuggestions = false;
      _isSelectingOnMap = false;
      _mapSelectionMode = '';
    });
    _dropFocusNode.unfocus();
    _updateMapAfterSelection();
  }

  Future<void> _updateMapAfterSelection() async {
    await _addLocationMarkers();

    if (_selectedPickup != null && _selectedDrop != null) {
      await _drawRouteUsingMapbox();
      setState(() => _showBottomSheet = true);
      _animationController.forward();
    } else if (_selectedPickup != null) {
      await _focusOnLocation(_selectedPickup!);
    } else if (_selectedDrop != null) {
      await _focusOnLocation(_selectedDrop!);
    } else {
      if (_routeAnnotation != null && _polylineAnnotationManager != null) {
        await _polylineAnnotationManager!.delete(_routeAnnotation!);
        _routeAnnotation = null;
      }
      setState(() => _showBottomSheet = false);
      _animationController.reverse();
    }
  }

  Future<void> _focusOnLocation(int index) async {
    if (_mapboxMap == null) return;
    final loc = _mapService.locations[index];

    await _mapboxMap!.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(loc.longitude, loc.latitude)),
        zoom: 14.0,
        padding: MbxEdgeInsets(
          top: 100,
          left: 50,
          bottom: 100,
          right: 50,
        ),
      ),
    );
  }

  Future<void> _drawRouteUsingMapbox() async {
    if (_mapboxMap == null || _selectedPickup == null || _selectedDrop == null) return;

    setState(() => _isLoading = true);

    try {
      final pickupLoc = _mapService.locations[_selectedPickup!];
      final dropLoc = _mapService.locations[_selectedDrop!];

      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
            '${pickupLoc.longitude},${pickupLoc.latitude};'
            '${dropLoc.longitude},${dropLoc.latitude}'
            '?geometries=geojson'
            '&overview=full'
            '&annotations=duration,distance'
            '&steps=true'
            '&access_token=$MAPBOX_ACCESS_TOKEN',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception('Mapbox error ${response.statusCode}');
      }

      final data = json.decode(response.body);

      if (data['routes'] == null || data['routes'].isEmpty) {
        throw Exception('No routes found');
      }

      final route = data['routes'][0];
      final coords = route['geometry']['coordinates'] as List;

      _fullRoute = coords
          .map((c) => Position(c[0].toDouble(), c[1].toDouble()))
          .toList();

      _routeDistance = route['distance'].toDouble();
      _routeDuration = route['duration'].toDouble();
      _routeDurationText = _formatDuration(_routeDuration);

      if (_routeAnnotation != null) {
        await _polylineAnnotationManager?.delete(_routeAnnotation!);
      }

      _routeAnnotation = await _polylineAnnotationManager?.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: _fullRoute),
          lineColor: const Color(0xFF00E5FF).value,
          lineWidth: 6.0,
          lineOpacity: 0.9,
        ),
      );

      await _fitCameraToRoute();

    } catch (e) {
      print('Route error: $e');
      _showSnackbar('Failed to fetch route', const Color(0xFFFF1744));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fitCameraToRoute() async {
    if (_mapboxMap == null || _fullRoute.isEmpty) return;

    try {
      double minLat = _fullRoute[0].lat.toDouble();
      double maxLat = _fullRoute[0].lat.toDouble();
      double minLng = _fullRoute[0].lng.toDouble();
      double maxLng = _fullRoute[0].lng.toDouble();

      for (var coord in _fullRoute) {
        final lat = coord.lat.toDouble();
        final lng = coord.lng.toDouble();
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lng < minLng) minLng = lng;
        if (lng > maxLng) maxLng = lng;
      }

      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;

      await _mapboxMap!.setCamera(
        CameraOptions(
          center: Point(coordinates: Position(centerLng, centerLat)),
          zoom: 13.0,
          padding: MbxEdgeInsets(
            top: 180,
            left: 40,
            bottom: _showBottomSheet ? 360 : 180,
            right: 40,
          ),
        ),
      );

    } catch (e) {
      print('Error fitting camera: $e');
    }
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.round());
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}min';
    } else {
      return '${duration.inMinutes}min';
    }
  }

  void _enableMapSelection(String mode) {
    setState(() {
      _isSelectingOnMap = true;
      _mapSelectionMode = mode;
      _showPickupSuggestions = false;
      _showDropSuggestions = false;
    });
    _pickupFocusNode.unfocus();
    _dropFocusNode.unfocus();
  }

  void _handleMapTap(MapContentGestureContext context) {
    if (!_isSelectingOnMap) return;

    final tappedLat = context.point.coordinates.lat.toDouble();
    final tappedLon = context.point.coordinates.lng.toDouble();

    double minDist = double.infinity;
    int? nearestIndex;

    for (int i = 0; i < _mapService.locations.length; i++) {
      if (_mapSelectionMode == 'pickup' && i == _selectedDrop) continue;
      if (_mapSelectionMode == 'drop' && i == _selectedPickup) continue;

      final loc = _mapService.locations[i];
      final dist = _calculateDistance(
        tappedLat,
        tappedLon,
        loc.latitude,
        loc.longitude,
      );

      if (dist < minDist) {
        minDist = dist;
        nearestIndex = i;
      }
    }

    if (nearestIndex != null && minDist < 5000) {
      if (_mapSelectionMode == 'pickup') {
        _selectPickupLocation(nearestIndex);
      } else {
        _selectDropLocation(nearestIndex);
      }
    } else {
      _showSnackbar('No location found nearby. Try tapping closer to a marker.', const Color(0xFFFF9100));
    }
  }

  Future<void> _confirmBooking() async {
    if (_selectedPickup == null || _selectedDrop == null) {
      _showSnackbar('Please select both pickup and drop-off locations', const Color(0xFFFF9100));
      return;
    }

    if (_selectedPickup == _selectedDrop) {
      _showSnackbar('Pickup and drop-off cannot be the same', const Color(0xFFFF9100));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _loadAvailableDrivers();

      if (_availableDrivers.isEmpty) {
        _showSnackbar('No drivers available at the moment', const Color(0xFFFF9100));
        setState(() => _isLoading = false);
        return;
      }

      final randomDriver = _availableDrivers[
      DateTime.now().millisecondsSinceEpoch % _availableDrivers.length
      ];

      final fare = _mapService.calculateFare(_routeDistance);

      final ride = RideRequest(
        id: const Uuid().v4(),
        riderUid: widget.user.uid,
        riderName: widget.user.username,
        pickupLocationIndex: _selectedPickup!,
        dropLocationIndex: _selectedDrop!,
        fare: fare,
        timestamp: DateTime.now(),
        status: 'pending',
        driverUid: randomDriver.uid,
        driverName: randomDriver.username,
      );

      await _firestore.collection('rides').doc(ride.id).set(ride.toMap());

      await _firestore.collection('drivers').doc(randomDriver.uid).update({
        'available': false,
      });

      if (!mounted) return;

      _showSnackbar('Booking confirmed! Driver ${randomDriver.username} is assigned.', const Color(0xFF00E676));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TrackingScreen(
            user: widget.user,
            ride: ride,
            driver: randomDriver,
          ),
        ),
      );

    } catch (e) {
      print('Error booking ride: $e');
      _showSnackbar('Error booking ride: $e', const Color(0xFFFF1744));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackbar(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map with dark style
          MapWidget(
            key: const ValueKey("mapWidget"),
            styleUri: MapboxStyles.DARK,
            onMapCreated: _onMapCreated,
            onTapListener: _handleMapTap,
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(73.0479, 33.6844)),
              zoom: 12.0,
            ),
          ),

          // Gradient overlay at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 200,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0A0A0F).withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Top search bar with glassmorphism
          Positioned(
            top: MediaQuery.of(context).padding.top + 15,
            left: 16,
            right: 16,
            child: Column(
              children: [
                _buildSearchField(
                  controller: _pickupController,
                  focusNode: _pickupFocusNode,
                  hint: 'Pickup Location',
                  icon: Icons.circle,
                  iconColor: const Color(0xFF00E676),
                  onMapSelect: () => _enableMapSelection('pickup'),
                  onChanged: (value) {
                    _filterLocationsByProximity(value);
                    setState(() => _showPickupSuggestions = true);
                  },
                ),
                const SizedBox(height: 10),
                _buildSearchField(
                  controller: _dropController,
                  focusNode: _dropFocusNode,
                  hint: 'Drop-off Location',
                  icon: Icons.location_on,
                  iconColor: const Color(0xFFFF1744),
                  onMapSelect: () => _enableMapSelection('drop'),
                  onChanged: (value) {
                    _filterLocationsByProximity(value);
                    setState(() => _showDropSuggestions = true);
                  },
                ),
              ],
            ),
          ),

          // Suggestions list with dark theme
          if (_showPickupSuggestions || _showDropSuggestions)
            Positioned(
              top: MediaQuery.of(context).padding.top + 155,
              left: 16,
              right: 16,
              child: _buildSuggestionsList(),
            ),

          // Map selection indicator with modern styling
          if (_isSelectingOnMap)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF00B8D4)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.touch_app_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Tap on map to select ${_mapSelectionMode}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom sheet with ride details
          if (_showBottomSheet)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildBottomSheet(),
                ),
              ),
            ),

          // Loading indicator with dark overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1E1E2E).withOpacity(0.95),
                        const Color(0xFF2A2A40).withOpacity(0.9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withOpacity(0.2),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onMapSelect,
    required Function(String) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E1E2E).withOpacity(0.95),
            const Color(0xFF2A2A40).withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: iconColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 15),
          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.map_rounded, color: Color(0xFF00E5FF), size: 22),
            onPressed: onMapSelect,
            tooltip: 'Select on map',
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Container(
        constraints: const BoxConstraints(maxHeight: 320),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1E1E2E).withOpacity(0.98),
              const Color(0xFF2A2A40).withOpacity(0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF00E5FF).withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemCount: _filteredLocations.length,
            separatorBuilder: (context, index) => Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    const Color(0xFF00E5FF).withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            itemBuilder: (context, index) {
              final item = _filteredLocations[index];
              final color = _showPickupSuggestions ? const Color(0xFF00E676) : const Color(0xFFFF1744);

              return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.location_on_rounded, color: color, size: 22),
                  ),
                  title: Text(
                    item.location.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                subtitle: Text(
                  '${(item.distance / 1000).toStringAsFixed(1)} km away',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: color,
                  size: 16,
                ),
                onTap: () {
                  if (_showPickupSuggestions) {
                    _selectPickupLocation(item.index);
                  } else {
                    _selectDropLocation(item.index);
                  }
                },
              );
            },
        ),
    );
  }

  Widget _buildBottomSheet() {
    final fare = _mapService.calculateFare(_routeDistance);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E1E2E).withOpacity(0.98),
            const Color(0xFF2A2A40).withOpacity(0.95),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF00E5FF).withOpacity(0.3),
            width: 2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Route info cards
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.straighten_rounded,
                      label: 'Distance',
                      value: '${(_routeDistance / 1000).toStringAsFixed(1)} km',
                      color: const Color(0xFF00E676),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.access_time_rounded,
                      label: 'Duration',
                      value: _routeDurationText,
                      color: const Color(0xFF00E5FF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.payments_rounded,
                      label: 'Fare',
                      value: 'Rs ${fare.toStringAsFixed(0)}',
                      color: const Color(0xFFFFD600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Location details
              _buildLocationRow(
                icon: Icons.circle,
                iconColor: const Color(0xFF00E676),
                label: 'Pickup',
                location: _selectedPickup != null
                    ? _mapService.locations[_selectedPickup!].name
                    : '',
              ),
              const SizedBox(height: 12),
              _buildLocationRow(
                icon: Icons.location_on,
                iconColor: const Color(0xFFFF1744),
                label: 'Drop-off',
                location: _selectedDrop != null
                    ? _mapService.locations[_selectedDrop!].name
                    : '',
              ),
              const SizedBox(height: 24),

              // Confirm button with gradient
              Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF00B8D4)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _confirmBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Confirm Booking',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String location,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: iconColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  location,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LocationWithDistance {
  final LocationModel location;
  final int index;
  final double distance;

  LocationWithDistance({
    required this.location,
    required this.index,
    required this.distance,
  });
}
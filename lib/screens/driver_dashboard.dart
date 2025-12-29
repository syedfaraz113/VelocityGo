import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models.dart';
import '../services/auth_service.dart';
import '../services/map_service.dart';
import 'login_screen.dart';

class DriverDashboard extends StatefulWidget {
  final UserModel user;
  final DriverModel driver;

  const DriverDashboard({
    Key? key,
    required this.user,
    required this.driver,
  }) : super(key: key);

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final IslamabadMapService _mapService = IslamabadMapService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late DriverModel _currentDriver;
  late Stream<DocumentSnapshot> _driverStream;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _currentDriver = widget.driver;
    _driverStream = _firestore.collection('drivers').doc(widget.driver.uid).snapshots();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleAvailability() async {
    try {
      final newStatus = !_currentDriver.available;
      await _firestore.collection('drivers').doc(widget.driver.uid).update({
        'available': newStatus,
      });

      setState(() {
        _currentDriver = DriverModel(
          uid: _currentDriver.uid,
          username: _currentDriver.username,
          latitude: _currentDriver.latitude,
          longitude: _currentDriver.longitude,
          available: newStatus,
          locationIndex: _currentDriver.locationIndex,
          rating: _currentDriver.rating,
          totalTrips: _currentDriver.totalTrips,
          earnings: _currentDriver.earnings,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus ? 'You are now available for rides' : 'You are now offline',
          ),
          backgroundColor: newStatus ? const Color(0xFF00E676) : const Color(0xFFFF9100),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: _driverStream,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.exists) {
            _currentDriver = DriverModel.fromMap(
                snapshot.data!.data() as Map<String, dynamic>);
          }

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0A0A0F),
                  const Color(0xFF1A1A2E),
                  const Color(0xFF16213E),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header with gradient overlay
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1A1A2E).withOpacity(0.5),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFD700).withOpacity(0.4),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.local_shipping_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 15),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Driver Dashboard',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  'Manage your driving experience',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFFFD700),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),

                        // Stats Grid
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Rating',
                                '${_currentDriver.rating.toStringAsFixed(1)}',
                                const Color(0xFFFFD700),
                                Icons.star_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                'Total Trips',
                                '${_currentDriver.totalTrips}',
                                const Color(0xFF00E5FF),
                                Icons.directions_car_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Earnings',
                                'Rs. ${_currentDriver.earnings.toStringAsFixed(0)}',
                                const Color(0xFF00E676),
                                Icons.account_balance_wallet_rounded,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatusCard(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Main Content Card with glassmorphism
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1E1E2E).withOpacity(0.95),
                            const Color(0xFF2A2A40).withOpacity(0.9),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(35),
                          topRight: Radius.circular(35),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: const Color(0xFF00E5FF).withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 28,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF00E5FF), Color(0xFF00B8D4)],
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Driver Information',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),

                          _buildInfoTile(
                            Icons.location_on_rounded,
                            'Current Location',
                            _mapService.locations[_currentDriver.locationIndex].name,
                            const Color(0xFFFF1744),
                          ),
                          const SizedBox(height: 8),

                          _buildInfoTile(
                            Icons.payments_rounded,
                            'Avg Fare per Trip',
                            'Rs. ${(_currentDriver.earnings / (_currentDriver.totalTrips > 0 ? _currentDriver.totalTrips : 1)).toStringAsFixed(0)}',
                            const Color(0xFF00E676),
                          ),
                          const SizedBox(height: 8),

                          _buildInfoTile(
                            Icons.verified_user_rounded,
                            'Account Type',
                            'Professional Driver',
                            const Color(0xFF00E5FF),
                          ),
                          const SizedBox(height: 12),

                          _buildInfoTile(
                            Icons.circle,
                            'Current Status',
                            _currentDriver.available
                                ? 'Available for rides'
                                : 'Currently on a trip',
                            _currentDriver.available
                                ? const Color(0xFF00E676)
                                : const Color(0xFFFF9100),
                          ),
                          const Spacer(),

                          // Toggle Availability Button
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _currentDriver.available
                                    ? [
                                  const Color(0xFFFF9100).withOpacity(0.8),
                                  const Color(0xFFFF6D00).withOpacity(0.8),
                                ]
                                    : [
                                  const Color(0xFF00E676).withOpacity(0.8),
                                  const Color(0xFF00C853).withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: (_currentDriver.available
                                      ? const Color(0xFFFF9100)
                                      : const Color(0xFF00E676))
                                      .withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _toggleAvailability,
                              icon: Icon(
                                _currentDriver.available
                                    ? Icons.pause_circle_rounded
                                    : Icons.play_circle_rounded,
                                size: 24,
                              ),
                              label: Text(
                                _currentDriver.available ? 'Go Offline' : 'Go Online',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Logout Button
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFFF1744).withOpacity(0.5),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await _authService.signOut();
                                if (context.mounted) {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (_) => const LoginScreen(),
                                    ),
                                        (route) => false,
                                  );
                                }
                              },
                              icon: const Icon(Icons.logout_rounded, size: 22),
                              label: const Text(
                                'Logout',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFFF1744),
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E1E2E).withOpacity(0.9),
            const Color(0xFF2A2A40).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.5),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final isAvailable = _currentDriver.available;
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1E1E2E).withOpacity(0.9),
                const Color(0xFF2A2A40).withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: (isAvailable ? const Color(0xFF00E676) : const Color(0xFFFF9100))
                  .withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isAvailable ? const Color(0xFF00E676) : const Color(0xFFFF9100))
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isAvailable ? Icons.check_circle_rounded : Icons.access_time_rounded,
                  color: isAvailable ? const Color(0xFF00E676) : const Color(0xFFFF9100),
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Status',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isAvailable ? const Color(0xFF00E676) : const Color(0xFFFF9100),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isAvailable ? const Color(0xFF00E676) : const Color(0xFFFF9100))
                              .withOpacity(_pulseController.value),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isAvailable ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isAvailable ? const Color(0xFF00E676) : const Color(0xFFFF9100),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.2),
                  color.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
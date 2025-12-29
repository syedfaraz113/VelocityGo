import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null; // User cancelled
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print('Error signing in with Google: $e');
      return null;
    }
  }

  // Create or update user document in Firestore
  Future<void> createUserDocument(User user, String role) async {
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        final userModel = UserModel(
          uid: user.uid,
          username: user.displayName ?? 'User',
          email: user.email ?? '',
          role: role,
          rating: 5.0,
          totalRides: 0,
        );

        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(userModel.toMap());

        // If driver, also create driver document
        if (role == 'driver') {
          final driverModel = DriverModel(
            uid: user.uid,
            username: user.displayName ?? 'Driver',
            latitude: 33.6844,
            longitude: 73.0479,
            available: true,
            locationIndex: 0,
            rating: 5.0,
            totalTrips: 0,
            earnings: 0.0,
          );

          await _firestore
              .collection('drivers')
              .doc(user.uid)
              .set(driverModel.toMap());
        }
      }
    } catch (e) {
      print('Error creating user document: $e');
    }
  }

  // Get user data from Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Get driver data from Firestore
  Future<DriverModel?> getDriverData(String uid) async {
    try {
      final doc = await _firestore.collection('drivers').doc(uid).get();
      if (doc.exists) {
        return DriverModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting driver data: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  // Update user rating
  Future<void> updateUserRating(String uid, double newRating) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'rating': newRating,
      });
    } catch (e) {
      print('Error updating rating: $e');
    }
  }

  // Increment total rides
  Future<void> incrementTotalRides(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'totalRides': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing rides: $e');
    }
  }
}
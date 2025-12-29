import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  MapboxOptions.setAccessToken(
    "pk.eyJ1IjoiZmFyYXo4NTAwIiwiYSI6ImNtam8xNXFzNjBqbWUzY3NkMjdlOWEweWcifQ.mR5-S1dI5CfzldAVjJ8jgg",
  );
  runApp(const VelocityGoApp());
}

class VelocityGoApp extends StatelessWidget {
  const VelocityGoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VelocityGo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
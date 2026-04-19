VelocityGo — Ride Hailing App

VelocityGo is a cross-platform ride-hailing mobile application built with Flutter and backed by Firebase. Inspired by services like inDrive and Careem, it connects riders with drivers and supports Android, iOS, and web platforms from a single codebase.

---

Table of Contents

- [Overview](#overview)
- [Tech Stack](#tech-stack)
- [File Structure](#file-structure)
- [Features](#features)
- [Getting Started](#getting-started)
- [Configuration](#configuration)
- [Author](#author)

---

Overview

VelocityGo is designed as a fully functional ride-hailing platform targeting the local Pakistani market. The app enables users to book rides, track drivers in real time, and complete rides — all through a smooth Flutter-based UI.

---

Tech Stack

| Technology | Purpose |
|------------|---------|
| Flutter / Dart (~81%) | Cross-platform UI framework |
| Firebase | Backend services (Auth, Firestore, Realtime DB) |
| C++ / CMake | Flutter native desktop plugins |

---

File Structure

```
VelocityGo/
├── lib/                  # Main Flutter/Dart application code
├── android/              # Android platform-specific files
├── ios/                  # iOS platform-specific files
├── web/                  # Web platform support
├── windows/              # Windows desktop support
├── linux/                # Linux desktop support
├── macos/                # macOS desktop support
├── assets/icon/          # App icons
├── test/                 # Unit/widget tests
├── firebase.json         # Firebase project configuration
├── pubspec.yaml          # Flutter dependencies and metadata
└── pubspec.lock          # Locked dependency versions
```

---

Features

- 🔐 User authentication (Firebase Auth)
- 📍 Real-time location and ride tracking
- 🗺️ Map integration for route visualization
- 🚘 Driver and rider matching
- 📱 Cross-platform: Android, iOS, Web
- 🔔 Push notifications support

---

Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x or later)
- [Firebase CLI](https://firebase.google.com/docs/cli)
- Android Studio or Xcode (for mobile builds)
- A Firebase project set up at [console.firebase.google.com](https://console.firebase.google.com)

Installation

```bash
# Clone the repository
git clone https://github.com/syedfaraz113/VelocityGo.git
cd VelocityGo

# Install Flutter dependencies
flutter pub get

# Run the app
flutter run
```

### Build for Android

```bash
flutter build apk --release
```

### Build for iOS

```bash
flutter build ios --release
```

---

Configuration

1. Create a Firebase project and add your Android/iOS apps
2. Download `google-services.json` (Android) or `GoogleService-Info.plist` (iOS)
3. Place them in the respective `android/app/` or `ios/Runner/` directories
4. Update `firebase.json` with your project details

---

Author

**Syed Faraz Ibne Saleem**
- GitHub: [@syedfaraz113](https://github.com/syedfaraz113)

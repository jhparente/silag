# SILAG

SILAG is an intelligent flood monitoring and early-warning mobile app built with Flutter and Firebase.

## Flutter Installation

Before you begin, ensure you have the Flutter SDK installed on your system.
Follow the official Flutter installation guide for your operating system:
- [Windows](https://docs.flutter.dev/get-started/install/windows)
- [macOS](https://docs.flutter.dev/get-started/install/macos)
- [Linux](https://docs.flutter.dev/get-started/install/linux)

Verify your installation by running:
```bash
flutter doctor
```
Resolve any missing dependencies (like Android Studio, Android SDKs, or command-line tools) highlighted by `flutter doctor`.

## Prerequisites

- Flutter SDK (compatible with Dart `^3.10.4`)
- Git
- Android Studio (for Android emulator/device support)
- Node.js and npm (only needed for Firebase CLI usage)

## How to Properly Run the App

1. **Clone the repository:**
```bash
git clone <your-repo-url>
cd silag
```

2. **Install project dependencies:**
```bash
flutter pub get
```

3. **Set up the Environment:**
Create an environment file named `.env` in the project root folder.
```env
OPENWEATHER_API_KEY=your_openweather_api_key_here
```

4. **Connect to the Local Backend (Crucial for Local Development):**
If you are running the Python FastAPI backend locally on `localhost:8000` and testing the Flutter app on an Android Emulator or physical Android device via USB, you **must** forward the device's port to your computer's localhost.

Run the following command in your terminal:
```bash
adb reverse tcp:8000 tcp:8000
```
*Note: Ensure your Android emulator is running or your device is connected via USB debugging before running this command.*

5. **Run the App:**
```bash
flutter run
```

## Firebase Setup Notes

This repository already includes Firebase platform configuration files and `lib/firebase_options.dart`.

If you need to reconnect to a different Firebase project:

```bash
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
flutterfire configure
```

## Common Commands

```bash
flutter pub get          # install dependencies
flutter run              # run on connected device/emulator
flutter test             # run tests
flutter clean            # clean build artifacts
```

## Folder Structure

```text
silag/
|- android/              # Android-specific native project files
|- assets/
|  |- icons/             # App image/icon assets
|- fonts/
|  |- poppins/           # Custom Poppins font files
|- ios/                  # iOS-specific native project files
|- lib/                  # Main Flutter/Dart application code
|  |- main.dart          # App entry point
|  |- main_screen.dart   # Main screen shell
|  |- firebase_options.dart
|  |- models/            # Data models
|  |- pages/             # UI pages/screens (login, etc.)
|  |- services/          # API, auth, weather, and app services
|  |- widgets/           # Reusable UI widgets
|- linux/                # Linux desktop runner
|- macos/                # macOS desktop runner
|- test/                 # Widget/unit tests
|- web/                  # Web target files
|- windows/              # Windows desktop runner
|- pubspec.yaml          # Dependencies and Flutter config
|- firebase.json         # Firebase project config
|- analysis_options.yaml # Lint and analyzer rules
|- README.md             # Project documentation
```

## Troubleshooting

- If `.env` is missing, app startup may fail before UI loads.
- If no device is detected, run `flutter devices` and start an emulator.
- If dependency resolution fails, run `flutter clean` then `flutter pub get`.
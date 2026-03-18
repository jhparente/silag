# SILAG

SILAG is an intelligent flood monitoring and early-warning mobile app built with Flutter and Firebase.

## Prerequisites

Install these before running the project:

- Flutter SDK (compatible with Dart `^3.10.4`)
- Git
- Android Studio (for Android emulator/device support)
- Xcode (macOS only, for iOS)
- Node.js and npm (only needed for Firebase CLI usage)

Useful checks:

```bash
flutter --version
flutter doctor
```

## Quick Start After Cloning

1. Clone the repository.

```bash
git clone <your-repo-url>
cd silag
```

2. Install project dependencies.

```bash
flutter pub get
```

3. Create an environment file named `.env` in the project root.

```env
OPENWEATHER_API_KEY=your_openweather_api_key_here
```

4. Run the app.

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
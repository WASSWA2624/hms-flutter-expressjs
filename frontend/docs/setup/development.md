# Development Setup

## Prerequisites

- Flutter 3.41 or newer on the stable channel.
- Android SDK for Android development.
- Xcode on macOS for iOS development.
- Xcode on macOS for macOS desktop development.
- Visual Studio with the C++ desktop workload for Windows desktop development.
- Windows Developer Mode for plugin symlink support on Windows desktop.
- Linux desktop build dependencies on Linux for Linux desktop development.

## First run

```sh
flutter pub get
flutter test
flutter run -d chrome --dart-define-from-file=env/development.json.example
flutter run -d windows --dart-define-from-file=env/development.json.example
```

See `environment.md` for all supported public configuration keys. Copy
`env/development.json.example` to ignored `env/development.json` only when local
values need to differ from the starter defaults.

## Hot reload development workflow

Flutter already provides the development reload loop that this template uses.
Run the app in debug mode, then update code while the app is running.

For the closest Nodemon-like workflow, use VS Code with the recommended Flutter
and Dart extensions. This repository configures:

- Auto save after a short delay.
- Flutter hot reload on save for active debug sessions.
- Debug launch targets for Web, Android, iOS, macOS, Windows, and Linux.

Open **Run and Debug** in VS Code and start one of these configurations:

- `Flutter: Web Chrome (development)`
- `Flutter: Android (development)`
- `Flutter: iOS (development)`
- `Flutter: macOS (development)`
- `Flutter: Windows (development)`
- `Flutter: Linux (development)`

When a launch target is running, normal Dart and widget changes are hot reloaded
after save. Use hot restart for startup, provider bootstrap, route table,
environment define, asset, dependency, generated code, or native platform
changes.

Terminal development uses the same Flutter debug runtime. Start the app with the
target platform command, then press `r` for hot reload, `R` for hot restart, and
`q` to quit.

```sh
flutter run -d chrome --dart-define-from-file=env/development.json.example
flutter run -d android --dart-define-from-file=env/development.json.example
flutter run -d ios --dart-define-from-file=env/development.json.example
flutter run -d macos --dart-define-from-file=env/development.json.example
```

Use `flutter devices` to find exact device IDs when more than one simulator,
emulator, browser, or physical device is available:

```sh
flutter devices
flutter run -d <deviceId> --dart-define-from-file=env/development.json.example
```

Platform requirements still apply: iOS and macOS require macOS with Xcode,
Android requires an emulator or physical device, and Web requires a supported
browser target such as Chrome.

## Windows desktop

Windows desktop builds need both Flutter's Windows target and host-level build
support:

```powershell
flutter config --enable-windows-desktop
start ms-settings:developers
```

Enable Developer Mode in the settings window so Flutter plugins can create
symlinks. Install Visual Studio 2022 with the **Desktop development with C++**
workload, including its default MSVC, Windows SDK, and CMake components.

After those prerequisites are installed, verify the host and run the app:

```powershell
flutter doctor -v
flutter run -d windows --dart-define-from-file=env/development.json.example
```

## Test commands

```sh
flutter test
flutter test test/shared/layout
flutter test integration_test
flutter test integration_test -d <deviceId>
flutter test --coverage
```

Use `flutter test` for unit and widget coverage. Use
`flutter test integration_test` for startup and navigation smoke coverage that
uses provider overrides instead of production services. Add `-d <deviceId>`
when more than one Flutter device is available.

## Platform notes

- Android, iOS, Web, Windows, macOS, and Linux project files are generated in
  this repository.
- iOS and macOS builds must run on macOS with Xcode.
- Windows desktop builds must run on Windows with Developer Mode enabled and
  the Visual Studio C++ desktop workload installed.
- Linux desktop builds must run on Linux with the required GTK and CMake tools.

## Line endings

The repository uses LF line endings by default. Windows batch and PowerShell
files keep CRLF line endings for native shell compatibility.

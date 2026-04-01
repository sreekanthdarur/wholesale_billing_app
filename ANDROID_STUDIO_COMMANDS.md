# Commands to run after opening the v6 codebase in Android Studio

## 1) Open terminal in project root

## 2) Check Flutter installation
flutter doctor -v

## 3) Get dependencies
flutter pub get

## 4) Format code
dart format .

## 5) Static analysis
flutter analyze

## 6) See connected devices
flutter devices

## 7) Run app on selected device
flutter run

## 8) Run in verbose mode if issue occurs
flutter run -v

## 9) Clean and rebuild if package/native issues occur
flutter clean
flutter pub get
flutter run

## 10) Build debug APK
flutter build apk --debug

## 11) Build release APK
flutter build apk --release

## 12) Build app bundle for Play Store
flutter build appbundle --release

## 13) Run tests if you add test cases later
flutter test

## 14) Useful package update checks
flutter pub outdated

## 15) Upgrade dependencies carefully
flutter pub upgrade

## 16) If Gradle/native Android issues occur
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run

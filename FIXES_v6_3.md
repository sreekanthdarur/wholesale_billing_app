# v6.3 Fixes
- Fixed `roundedTarget` typing to explicit `double`
- Restored `TextFormField(initialValue: ...)` in draft and invoice editor screens
- Kept `DropdownButtonFormField(value: ...)` because your Flutter SDK still requires it
- Kept older `speech_to_text` API because your installed plugin/SKD combo still accepts it

## Run next
```bash
flutter pub get
dart format .
flutter analyze
flutter run -d 6db9fa52
```

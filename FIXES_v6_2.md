# v6.2 Fixes
- Reverted all `DropdownButtonFormField` widgets back to `value:` because your Flutter SDK requires `value` and does not support `initialValue`
- Added explicit `DropdownMenuItem<String>` typing to remove `dynamic` item list errors
- Reverted `speech_to_text` listen call to older API using `partialResults` and `listenMode`
- Tightened `double` typing in `auto_amount_service.dart`
- Kept corrected widget test reference

## Run next
```bash
flutter pub get
dart format .
flutter analyze
flutter run -d 6db9fa52
```

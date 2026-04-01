# Wholesale Billing App v6 Final

A Flutter-based offline-first wholesale billing scaffold with manual, voice, camera, auto-amount, saved-invoice, print-preview, and Excel export flows.

## Included in this build
- Manual invoice draft -> review -> save
- Saved invoice browse/edit
- Auto-generated invoice numbers
- Grouping by today / month / month-year / date
- Voice invoice flow using `speech_to_text`
- Camera OCR flow using `google_mlkit_text_recognition`
- Auto amount invoice generation
- SQLite local storage
- Print preview foundation
- Standard Excel export
- Tally-ready Excel export

## Important notes
This source was **statically reviewed**, but it was **not fully compiled and run in this environment** because Flutter/Dart SDK is not available here.  
You should treat this as an implementation-ready source bundle that still needs local validation in Android Studio.

## Key packages
- sqflite
- path
- path_provider
- image_picker
- google_mlkit_text_recognition
- speech_to_text
- excel

## Android setup reminders
Update `android/app/src/main/AndroidManifest.xml` with at least:
- microphone permission
- camera permission
- photo/media read permission where needed
- speech recognition query block for Android 11+

Suggested entries:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>

<queries>
    <intent>
        <action android:name="android.speech.RecognitionService" />
    </intent>
</queries>
```

For newer Android versions, storage/media permission handling may differ.

## iOS setup reminders
Update `ios/Runner/Info.plist` with:
- microphone usage description
- camera usage description
- photo library usage description
- speech recognition usage description

## Current limitations
- Thermal printer hardware integration is not implemented yet
- Tally export is Excel-layout oriented, not full XML voucher generation
- OCR quality depends on image clarity and ML Kit support on the device
- Voice recognition quality depends on device ASR engine, mic quality, and permissions

## Recommended next stabilization pass
1. Run `flutter pub get`
2. Run `flutter analyze`
3. Run on a real Android device
4. Fix any Android/iOS permission issues
5. Validate OCR and mic flows on-device
6. Then add thermal printer integration

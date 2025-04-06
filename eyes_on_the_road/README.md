# eyes_on_the_road

A Flutter-based navigation application with real-time obstacle detection using YOLO nano models. This app helps users navigate while providing visual warnings about obstacles in their path.

## Prerequisites

Before you begin, ensure you have the following installed:
- [Flutter](https://flutter.dev/docs/get-started/install) (2.10.0 or higher)
- [Dart](https://dart.dev/get-dart) (2.16.0 or higher)
- [Android Studio](https://developer.android.com/studio) or [Xcode](https://developer.apple.com/xcode/) (for iOS development)
- [Git](https://git-scm.com/downloads)

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/FoxHui1759/A-mobile-application-that-assists-individuals-with-visual-impairment-to-travel-in-Hong-Kong
cd navigation-assistant
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 4. Set Up Google Maps API Key (for navigation)

1. Obtain a Google Maps API key from the [Google Cloud Console](https://console.cloud.google.com/)
2. Enable the following APIs:
    - Directions API
    - Maps SDK for Android/iOS
    - Places API
3. Add the API Key at the root of `eyes_on_the_road` folder with content `GOOGLE_MAPS_API_KEY=[Your API Key]`


### 5. Required Permissions
   The application requires several permissions to function properly. These are already configured in the AndroidManifest.xml file when you pull from Git.
   Android Permissions
   The app uses the following permissions:
```xml
<!-- Internet permissions -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- Location permissions -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

<!-- For devices running Android 10 (API level 29) and above -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />

<!-- Activity recognition for motion detection -->
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />

<!-- Camera and microphone for Object Recognition and Voice Input features -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />

<!-- Storage permissions -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>

<!-- For devices running Android 12 and above -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
```

#### iOS
Add the following to your `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access for obstacle detection</string>
```

## Building and Running the App

### Debug Mode

```bash
# For Android
flutter run

# For iOS
flutter run -d ios
```

### Release Mode

```bash
# For Android
flutter build apk --release

# For iOS
flutter build ios --release
```


## Using the Application

### Navigation

1. Launch the app and wait for location services to initialize
2. Tap "Set Destination" button
3. Enter your destination in the input field
4. Tap "Start" to begin navigation
5. Follow the on-screen directions

### Obstacle Detection Features

The app automatically detects obstacles while you navigate:

- **Warning Banner**: Appears at the top when obstacles are detected
- **Guidance**: Provides instructions on how to avoid obstacles
- **Bounding Boxes**: Visual indicators showing detected obstacles
- **Auto-detection**: Works with people, vehicles, animals, and other common obstacles

### Tips for Best Results

- Hold the phone upright at eye level
- Ensure the camera lens is clean
- Use in well-lit environments for best detection
- For walking navigation, keep the app open and visible
- Allow camera permissions when prompted


## Troubleshooting

### Camera Issues
- Restart the app if the camera doesn't initialize
- Check camera permissions in device settings
- Ensure no other apps are using the camera

### Navigation Issues
- Verify internet connectivity
- Check that location services are enabled
- Ensure Google Maps API key is correctly configured

### Obstacle Detection Issues
- If detection is slow, try reducing background apps
- Clean camera lens if detections seem inaccurate
- Restart the app if model fails to load


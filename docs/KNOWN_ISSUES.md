# Known issues

| # | Found | Issue | Suspects | Status |
|---|---|---|---|---|
| 1 | v0.1.0-beta | Samsung Galaxy S21: installer says the APK is "not compatible". | Wrong split APK (x86_64 / armeabi-v7a instead of arm64-v8a or universal); Play Protect / older install with another signature; minSdk/targetSdk from Flutter defaults. | Release notes now say which APK to install (arm64-v8a / universal). If it persists with those, run `adb install` for the exact error. |
| 2 | v0.1.0-beta | Launcher showed the default Flutter icon. | Icon was added after v0.1.0 (#48). | Fixed in v0.2.0-beta; adaptive (Android 8+) icon still to add. |
| 3 | v0.3.0-beta | No vibration on key press (user report). | `HapticFeedback` depends on the system touch-feedback setting. | Fixed after v0.3.0: Vibrator service via `wcalc/haptics` channel + VIBRATE permission; verify on the next APK. |

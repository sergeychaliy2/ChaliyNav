package com.example.chaliy_nav

// local_auth (biometrics) requires the activity to be a FragmentActivity
// on Android 29+. Using the plain FlutterActivity silently fails or shows
// a "cannot be authenticated" on some OEMs.
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()

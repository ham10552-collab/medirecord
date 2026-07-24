import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => windows;

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
    appId: '1:000000000000:android:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'medirecord-placeholder',
    authDomain: 'medirecord-placeholder.firebaseapp.com',
    storageBucket: 'medirecord-placeholder.appspot.com',
  );
}

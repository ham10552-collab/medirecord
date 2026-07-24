# MediRecord - Setup Guide

## Prerequisites
1. **Flutter SDK** (3.16+) – https://flutter.dev/docs/get-started/install
2. **Android Studio** (for Android SDK) – https://developer.android.com/studio
3. **Firebase project** – https://console.firebase.google.com

## Quick Setup

### 1. Create a Firebase project
- Go to https://console.firebase.google.com and create a project
- Add Android app with package name: `com.example.medirecord`
- Download `google-services.json` and place it in `android/app/`

### 2. Enable Authentication
- In Firebase Console → Authentication → Sign-in method
- Enable **Email/Password** sign-in

### 3. Build the APK
```bash
# Double-click the build script
build_apk.bat

# OR manually:
flutter pub get
flutter build apk --release
```

The APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

## First Run

1. Install the APK on your Android phone
2. Open the app
3. Create an admin account (Sign Up with role = Admin)
4. Start adding patients and records

## Features Overview

| Feature | Details |
|---------|---------|
| **Offline-first** | All data stored locally in SQLite. No internet needed |
| **Patients** | Add, edit, search by name/phone |
| **Medical History** | Track conditions, surgeries, allergies |
| **Examinations** | Full physical exams with vitals (BP, HR, temp, SpO2, etc.) |
| **Investigations** | Lab tests with abnormal flagging |
| **Medications** | Drug prescriptions with dosage, frequency, active status |
| **Multi-user** | Admin, Doctor, Nurse roles |
| **Biometric** | Fingerprint/Face ID unlock |
| **Reports** | PDF patient summaries, CSV export |

## File Structure
```
medirecord/
├── lib/
│   ├── main.dart              # Entry point
│   ├── app.dart               # App widget with router
│   ├── core/                  # Core infrastructure
│   │   ├── auth/              # Firebase auth + biometric
│   │   ├── database/          # SQLite database helper
│   │   ├── router/            # GoRouter navigation
│   │   ├── theme/             # Material 3 theme
│   │   └── utils/             # Constants, validators
│   ├── features/              # Feature modules
│   │   ├── auth/              # Login screen
│   │   ├── dashboard/         # Main dashboard
│   │   ├── patients/          # Patient CRUD + detail
│   │   ├── history/           # Medical history form
│   │   ├── examinations/      # Examination form
│   │   ├── investigations/    # Lab test form
│   │   ├── medications/       # Medication form
│   │   ├── reports/           # PDF/CSV export
│   │   └── admin/             # User management
│   └── shared/                # Shared models & widgets
├── android/                   # Android configuration
├── pubspec.yaml               # Dependencies
└── build_apk.bat              # One-click build script
```

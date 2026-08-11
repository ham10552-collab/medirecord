import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/welcome/welcome_screen.dart';
import '../../features/license/license_activation_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/network/role_screen.dart';
import '../../features/network/secretary_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/patients/patient_list_screen.dart';
import '../../features/patients/patient_detail_screen.dart';
import '../../features/patients/patient_form_screen.dart';
import '../../features/history/history_form_screen.dart';
import '../../features/examinations/examination_form_screen.dart';
import '../../features/investigations/investigation_form_screen.dart';
import '../../features/medications/medication_form_screen.dart';
import '../../features/surgeries/surgery_form_screen.dart';
import '../../features/allergies/allergy_form_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/prescriptions/prescription_form_screen.dart';
import '../../features/admin/user_management_screen.dart';
import '../../features/bookings/booking_screen.dart';
import '../../features/setup/setup_screen.dart';
import '../../features/support/contact_screen.dart';
import '../../features/pharmacy/pharmacy_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      // One role per computer. The device role (set on the role screen and
      // stored per machine) gates every screen: a secretary machine cannot
      // reach the doctor dashboard/patients/reports/pharmacy and a pharmacy
      // machine can only use the pharmacy.
      final role = ref.read(deviceRoleProvider).valueOrNull;
      if (role == null) return null;
      final loc = state.matchedLocation;
      if (role == 'pharmacist') {
        final blocked = loc == '/' ||
            loc.startsWith('/patients') ||
            loc == '/reports' ||
            loc == '/bookings' ||
            loc == '/secretary' ||
            loc.startsWith('/admin');
        if (blocked) return '/pharmacy';
      } else if (role == 'secretary') {
        final blocked = loc == '/' ||
            loc.startsWith('/patients') ||
            loc == '/reports' ||
            loc == '/pharmacy' ||
            loc.startsWith('/admin');
        if (blocked) return '/secretary';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: '/license', builder: (context, state) => const LicenseActivationScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/role', builder: (context, state) => const RoleScreen()),
      GoRoute(path: '/secretary', builder: (context, state) => const SecretaryScreen()),
      GoRoute(
        path: '/',
        builder: (context, state) {
          final role = ref.read(deviceRoleProvider).valueOrNull;
          if (role == 'pharmacist') return const PharmacyScreen();
          if (role == 'secretary') return const SecretaryScreen();
          return const DashboardScreen();
        },
      ),
      GoRoute(
        path: '/patients',
        builder: (context, state) => const PatientListScreen(),
      ),
      GoRoute(
        path: '/patients/add',
        builder: (context, state) => const PatientFormScreen(),
      ),
      GoRoute(
        path: '/patients/edit/:id',
        builder: (context, state) => PatientFormScreen(
          patientId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/patients/:id',
        builder: (context, state) => PatientDetailScreen(
          patientId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/patients/:id/history/add',
        builder: (context, state) => HistoryFormScreen(
          patientId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/patients/:id/examinations/add',
        builder: (context, state) => ExaminationFormScreen(
          patientId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/patients/:id/investigations/add',
        builder: (context, state) => InvestigationFormScreen(
          patientId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/patients/:id/medications/add',
        builder: (context, state) => MedicationFormScreen(
          patientId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/patients/:id/surgeries/add',
        builder: (context, state) => SurgeryFormScreen(
          patientId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/patients/:id/allergies/add',
        builder: (context, state) => AllergyFormScreen(
          patientId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/patients/:id/prescriptions/add',
        builder: (context, state) => PrescriptionFormScreen(
          patientId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/bookings',
        builder: (context, state) => const BookingScreen(),
      ),
      GoRoute(
        path: '/pharmacy',
        builder: (context, state) => const PharmacyScreen(),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const UserManagementScreen(),
      ),
      GoRoute(
        path: '/setup',
        builder: (context, state) => const SetupScreen(),
      ),
      GoRoute(
        path: '/contact',
        builder: (context, state) => const ContactScreen(),
      ),
    ],
  );
});

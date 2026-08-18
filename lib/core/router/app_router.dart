import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/welcome/welcome_screen.dart';
import '../../features/license/license_activation_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/network/role_screen.dart';
import '../../features/network/secretary_screen.dart';
import '../../features/lab/lab_screen.dart';
import '../../features/lab/lab_orders_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/patients/patient_list_screen.dart';
import '../../features/patients/patient_detail_screen.dart';
import '../../features/patients/patient_form_screen.dart';
import '../../features/history/history_form_screen.dart';
import '../../features/examinations/examination_form_screen.dart';
import '../../features/investigations/investigation_form_screen.dart';
import '../../features/medications/medication_form_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/prescriptions/prescription_form_screen.dart';
import '../../features/admin/user_management_screen.dart';
import '../../features/bookings/booking_screen.dart';
import '../../features/setup/setup_screen.dart';
import '../../features/support/contact_screen.dart';
import '../../features/pharmacy/pharmacy_screen.dart';
import '../../features/departments/departments_screen.dart';
import '../../features/staff/staff_screen.dart';
import '../../shared/widgets/app_shell.dart';
import '../../core/network/lab_notifications.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: appNavigatorKey,
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
            loc == '/lab' ||
            loc.startsWith('/admin');
        // /license and /role stay reachable (activate/switch while in trial).
        if (blocked && loc != '/license' && loc != '/role') return '/pharmacy';
      } else if (role == 'lab') {
        final allowed = loc == '/lab' ||
            loc == '/setup' ||
            loc == '/contact' ||
            loc == '/license' ||
            loc == '/role';
        if (!allowed) return '/lab';
      } else if (role == 'secretary') {
        final blocked = loc == '/' ||
            loc.startsWith('/patients') ||
            loc == '/reports' ||
            loc == '/pharmacy' ||
            loc == '/lab' ||
            loc.startsWith('/admin');
        // A secretary never sees the doctor's screens; /patients routes open
        // the secretary's own screen instead (the tab is chosen from the nav).
        if (blocked && loc != '/license' && loc != '/role') return '/secretary';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: '/license', builder: (context, state) => const LicenseActivationScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/role', builder: (context, state) => const RoleScreen()),
      GoRoute(
        path: '/secretary',
        builder: (context, state) => const AppShell(child: SecretaryScreen()),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) {
          final role = ref.read(deviceRoleProvider).valueOrNull;
          if (role == 'pharmacist') return const AppShell(child: PharmacyScreen());
          if (role == 'secretary') return const AppShell(child: SecretaryScreen());
          if (role == 'lab') return const AppShell(child: LabScreen());
          return const AppShell(child: DashboardScreen());
        },
      ),
      GoRoute(
        path: '/patients',
        builder: (context, state) => const AppShell(child: PatientListScreen()),
      ),
      GoRoute(
        path: '/patients/add',
        builder: (context, state) => const AppShell(child: PatientFormScreen()),
      ),
      GoRoute(
        path: '/patients/edit/:id',
        builder: (context, state) => AppShell(
          child: PatientFormScreen(
            patientId: state.pathParameters['id'],
          ),
        ),
      ),
      GoRoute(
        path: '/patients/:id',
        builder: (context, state) => AppShell(
          child: PatientDetailScreen(
            patientId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/patients/:id/history/add',
        builder: (context, state) => AppShell(
          child: HistoryFormScreen(
            patientId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/patients/:id/examinations/add',
        builder: (context, state) => AppShell(
          child: ExaminationFormScreen(
            patientId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/patients/:id/investigations/add',
        builder: (context, state) => AppShell(
          child: InvestigationFormScreen(
            patientId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/patients/:id/medications/add',
        builder: (context, state) => AppShell(
          child: MedicationFormScreen(
            patientId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/patients/:id/prescriptions/add',
        builder: (context, state) => AppShell(
          child: PrescriptionFormScreen(
            patientId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const AppShell(child: ReportsScreen()),
      ),
      GoRoute(
        path: '/bookings',
        builder: (context, state) => const AppShell(child: BookingScreen()),
      ),
      GoRoute(
        path: '/departments',
        builder: (context, state) => const AppShell(child: DepartmentsScreen()),
      ),
      GoRoute(
        path: '/staff',
        builder: (context, state) => const AppShell(child: StaffScreen()),
      ),
      GoRoute(
        path: '/pharmacy',
        builder: (context, state) => const AppShell(child: PharmacyScreen()),
      ),
      GoRoute(
        path: '/lab',
        builder: (context, state) => const AppShell(child: LabScreen()),
      ),
      GoRoute(
        path: '/lab-orders',
        builder: (context, state) => const AppShell(child: LabOrdersScreen()),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const AppShell(child: UserManagementScreen()),
      ),
      GoRoute(
        path: '/setup',
        builder: (context, state) => const AppShell(child: SetupScreen()),
      ),
      GoRoute(
        path: '/contact',
        builder: (context, state) => const AppShell(child: ContactScreen()),
      ),
    ],
  );
});

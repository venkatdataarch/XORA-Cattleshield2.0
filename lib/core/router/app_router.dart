import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/farmer_registration_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';

// Farmer screens
import '../../features/farmer/dashboard/presentation/screens/farmer_dashboard_screen.dart';
import '../../features/farmer/animal/presentation/screens/animal_list_screen.dart';
import '../../features/farmer/animal/presentation/screens/animal_onboarding_screen.dart';
import '../../features/farmer/animal/presentation/screens/animal_detail_screen.dart';
import '../../features/farmer/proposal/presentation/screens/proposal_list_screen.dart';
import '../../features/farmer/proposal/presentation/screens/proposal_form_screen.dart';
import '../../features/farmer/proposal/presentation/screens/proposal_detail_screen.dart';
import '../../features/farmer/claim/presentation/screens/claim_list_screen.dart';
import '../../features/farmer/claim/presentation/screens/claim_form_screen.dart';
import '../../features/farmer/claim/presentation/screens/claim_detail_screen.dart';
import '../../features/farmer/claim/presentation/screens/claim_evidence_upload_screen.dart';
import '../../features/farmer/policy/presentation/screens/policy_list_screen.dart';
import '../../features/farmer/policy/presentation/screens/policy_detail_screen.dart';

// Admin screens
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/audit_log_screen.dart';
import '../../features/admin/presentation/screens/fraud_alerts_screen.dart';

// Vet screens
import '../../features/vet/dashboard/presentation/screens/vet_dashboard_screen.dart';
import '../../features/vet/review/presentation/screens/vet_proposal_review_screen.dart';
import '../../features/vet/review/presentation/screens/vet_claim_review_screen.dart';
import '../../features/vet/certificate/presentation/screens/certificate_form_screen.dart';
import '../../features/vet/certificate/presentation/screens/certificate_preview_screen.dart';

import '../constants/app_colors.dart';
import 'auth_guard.dart';
import 'route_names.dart';

// ---------------------------------------------------------------------------
// Navigator keys
// ---------------------------------------------------------------------------

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _farmerShellKey = GlobalKey<NavigatorState>();
final _vetShellKey = GlobalKey<NavigatorState>();

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// A [ChangeNotifier] that listens to the auth provider and notifies GoRouter
/// when a redirect check is needed — without rebuilding the entire router.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthChangeNotifier(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      return AuthGuard.redirect(authState, state.matchedLocation);
    },
    routes: [
      // -------------------------------------------------------------------
      // Auth routes
      // -------------------------------------------------------------------
      GoRoute(
        path: '/splash',
        name: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
        routes: [
          GoRoute(
            path: 'otp',
            name: RouteNames.otpVerification,
            builder: (context, state) {
              final phone = state.uri.queryParameters['phone'] ?? '';
              return OtpVerificationScreen(phone: phone);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/register/farmer',
        name: RouteNames.farmerRegistration,
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          return FarmerRegistrationScreen(phone: phone);
        },
      ),

      // -------------------------------------------------------------------
      // Farmer shell (bottom navigation)
      // -------------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _FarmerScaffold(navigationShell: navigationShell);
        },
        branches: [
          // Home
          StatefulShellBranch(
            navigatorKey: _farmerShellKey,
            routes: [
              GoRoute(
                path: '/farmer',
                name: RouteNames.farmerDashboard,
                builder: (context, state) => const FarmerDashboardScreen(),
                routes: [
                  GoRoute(
                    path: 'proposals',
                    name: RouteNames.proposalList,
                    builder: (context, state) => const ProposalListScreen(),
                    routes: [
                      GoRoute(
                        path: 'new/:animalId',
                        name: RouteNames.proposalForm,
                        builder: (context, state) => ProposalFormScreen(
                          animalId: state.pathParameters['animalId'] ?? '',
                        ),
                      ),
                      GoRoute(
                        path: ':id',
                        name: RouteNames.proposalDetail,
                        builder: (context, state) => ProposalDetailScreen(
                          proposalId: state.pathParameters['id'] ?? '',
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'claims',
                    name: RouteNames.claimList,
                    builder: (context, state) => const ClaimListScreen(),
                    routes: [
                      GoRoute(
                        path: 'new/:policyId',
                        name: RouteNames.claimForm,
                        builder: (context, state) => ClaimFormScreen(
                          policyId: state.pathParameters['policyId'] ?? '',
                        ),
                      ),
                      GoRoute(
                        path: ':id',
                        name: RouteNames.claimDetail,
                        builder: (context, state) => ClaimDetailScreen(
                          claimId: state.pathParameters['id'] ?? '',
                        ),
                        routes: [
                          GoRoute(
                            path: 'evidence',
                            name: RouteNames.claimEvidence,
                            builder: (context, state) =>
                                ClaimEvidenceUploadScreen(
                              claimId: state.pathParameters['id'] ?? '',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Animals
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/farmer/animals',
                name: RouteNames.animalList,
                builder: (context, state) => const AnimalListScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    name: RouteNames.animalOnboarding,
                    builder: (context, state) =>
                        const AnimalOnboardingScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    name: RouteNames.animalDetail,
                    builder: (context, state) => AnimalDetailScreen(
                      animalId: state.pathParameters['id'] ?? '',
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Policies
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/farmer/policies',
                name: RouteNames.policyList,
                builder: (context, state) => const PolicyListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: RouteNames.policyDetail,
                    builder: (context, state) => PolicyDetailScreen(
                      policyId: state.pathParameters['id'] ?? '',
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/farmer/profile',
                name: RouteNames.profile,
                builder: (context, state) =>
                    const _Placeholder(title: 'Profile'),
              ),
            ],
          ),
        ],
      ),

      // -------------------------------------------------------------------
      // Vet shell (bottom navigation)
      // -------------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _VetScaffold(navigationShell: navigationShell);
        },
        branches: [
          // Dashboard
          StatefulShellBranch(
            navigatorKey: _vetShellKey,
            routes: [
              GoRoute(
                path: '/vet',
                name: RouteNames.vetDashboard,
                builder: (context, state) => const VetDashboardScreen(),
              ),
            ],
          ),
          // Reviews
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/vet/reviews',
                builder: (context, state) =>
                    const _Placeholder(title: 'Vet Reviews'),
                routes: [
                  GoRoute(
                    path: 'proposals/:id',
                    name: RouteNames.vetProposalReview,
                    builder: (context, state) => VetProposalReviewScreen(
                      proposalId: state.pathParameters['id'] ?? '',
                    ),
                  ),
                  GoRoute(
                    path: 'claims/:id',
                    name: RouteNames.vetClaimReview,
                    builder: (context, state) => VetClaimReviewScreen(
                      claimId: state.pathParameters['id'] ?? '',
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Certificates
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/vet/certificates',
                builder: (context, state) =>
                    const _Placeholder(title: 'Certificates'),
                routes: [
                  GoRoute(
                    path: 'new/:type/:entityId',
                    name: RouteNames.certificateForm,
                    builder: (context, state) => CertificateFormScreen(
                      typeString: state.pathParameters['type'] ?? '',
                      entityId: state.pathParameters['entityId'] ?? '',
                    ),
                  ),
                  GoRoute(
                    path: ':id/preview',
                    name: RouteNames.certificatePreview,
                    builder: (context, state) => CertificatePreviewScreen(
                      certificateId: state.pathParameters['id'] ?? '',
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/vet/profile',
                builder: (context, state) =>
                    const _Placeholder(title: 'Vet Profile'),
              ),
            ],
          ),
        ],
      ),

      // -------------------------------------------------------------------
      // Admin shell (bottom navigation)
      // -------------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _AdminScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin',
                name: RouteNames.adminDashboard,
                builder: (context, state) => const AdminDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/audit-logs',
                name: RouteNames.auditLogs,
                builder: (context, state) => const AuditLogScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/fraud-alerts',
                name: RouteNames.fraudAlerts,
                builder: (context, state) => const FraudAlertsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/profile',
                builder: (context, state) =>
                    const _Placeholder(title: 'Admin Profile'),
              ),
            ],
          ),
        ],
      ),

      // -------------------------------------------------------------------
      // Scan routes (accessible to all authenticated roles)
      // -------------------------------------------------------------------
      GoRoute(
        path: '/scan/muzzle/:animalId',
        name: RouteNames.muzzleCapture,
        builder: (context, state) => _Placeholder(
          title: 'Muzzle Capture (${state.pathParameters['animalId']})',
        ),
      ),
      GoRoute(
        path: '/scan/muzzle/identify/:animalId',
        name: RouteNames.muzzleIdentify,
        builder: (context, state) => _Placeholder(
          title: 'Muzzle Identify (${state.pathParameters['animalId']})',
        ),
      ),
      GoRoute(
        path: '/scan/muzzle/result',
        name: RouteNames.muzzleResult,
        builder: (context, state) =>
            const _Placeholder(title: 'Muzzle Result'),
      ),
      GoRoute(
        path: '/scan/health/:animalId',
        name: RouteNames.healthCapture,
        builder: (context, state) => _Placeholder(
          title: 'Health Capture (${state.pathParameters['animalId']})',
        ),
      ),
      GoRoute(
        path: '/scan/health/result',
        name: RouteNames.healthResult,
        builder: (context, state) =>
            const _Placeholder(title: 'Health Result'),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.matchedLocation,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

// ---------------------------------------------------------------------------
// Farmer scaffold with bottom navigation
// ---------------------------------------------------------------------------

class _FarmerScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const _FarmerScaffold({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.pets_outlined),
            selectedIcon: Icon(Icons.pets),
            label: 'Animals',
          ),
          NavigationDestination(
            icon: Icon(Icons.policy_outlined),
            selectedIcon: Icon(Icons.policy),
            label: 'Policies',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vet scaffold with bottom navigation
// ---------------------------------------------------------------------------

class _VetScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const _VetScaffold({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.rate_review_outlined),
            selectedIcon: Icon(Icons.rate_review),
            label: 'Reviews',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'Certificates',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Admin scaffold with bottom navigation
// ---------------------------------------------------------------------------

class _AdminScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const _AdminScaffold({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Audit Trail',
          ),
          NavigationDestination(
            icon: Icon(Icons.warning_amber_outlined),
            selectedIcon: Icon(Icons.warning_amber),
            label: 'Fraud Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholder screen for routes whose real screens haven't been built yet
// ---------------------------------------------------------------------------

class _Placeholder extends StatelessWidget {
  final String title;

  const _Placeholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

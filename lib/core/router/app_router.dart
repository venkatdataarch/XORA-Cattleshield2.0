import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/agent_registration_screen.dart';
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
import '../../features/farmer/claim/presentation/screens/select_policy_for_claim_screen.dart';
import '../../features/farmer/claim/presentation/screens/claim_form_screen.dart';
import '../../features/farmer/claim/presentation/screens/claim_detail_screen.dart';
import '../../features/farmer/claim/presentation/screens/claim_evidence_upload_screen.dart';
import '../../features/farmer/policy/presentation/screens/policy_list_screen.dart';
import '../../features/farmer/policy/presentation/screens/policy_detail_screen.dart';

// Admin screens
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/admin_proposal_review_screen.dart';
import '../../features/admin/presentation/screens/audit_log_screen.dart';
import '../../features/admin/presentation/screens/fraud_alerts_screen.dart';

// Photo capture
import '../../features/ai/photo_capture/presentation/screens/guided_photo_capture_screen.dart';
// Muzzle identify
import '../../features/ai/muzzle_scan/presentation/screens/standalone_identify_screen.dart';
import '../../features/ai/muzzle_scan/presentation/screens/native_muzzle_camera_screen.dart';
import '../../features/ai/muzzle_scan/presentation/screens/muzzle_result_screen.dart';
import '../../features/ai/health_scan/presentation/screens/health_capture_screen.dart';
import '../../features/ai/health_scan/presentation/screens/health_result_screen.dart';
import '../../features/farmer/animal/domain/animal_model.dart';

// Profile (shared widget with edit capability)
import '../../shared/widgets/profile_screen.dart';

// Vet screens
import '../../features/vet/dashboard/presentation/screens/vet_dashboard_screen.dart';
import '../../features/vet/review/presentation/screens/vet_proposal_review_screen.dart';
import '../../features/vet/review/presentation/screens/vet_claim_review_screen.dart';
import '../../features/vet/review/presentation/screens/vet_reviews_list_screen.dart';
import '../../features/vet/certificate/presentation/screens/certificate_form_screen.dart';
import '../../features/vet/certificate/presentation/screens/certificate_preview_screen.dart';
import '../../features/vet/certificate/presentation/screens/vet_certificates_list_screen.dart';
import '../../features/vet/profile/presentation/screens/vet_profile_screen.dart';

// Admin screens (profile)
import '../../features/admin/presentation/screens/admin_profile_screen.dart';

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
      GoRoute(
        path: '/register/agent',
        name: 'agent-registration',
        builder: (context, state) => const AgentRegistrationScreen(),
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
                    path: 'claims',
                    name: RouteNames.claimList,
                    builder: (context, state) => const ClaimListScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) => const SelectPolicyForClaimScreen(),
                      ),
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
          // Proposals (tracking)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/farmer/proposals',
                name: 'farmer-proposals',
                builder: (context, state) => const ProposalListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    name: 'farmer-proposal-detail',
                    builder: (context, state) => ProposalDetailScreen(
                      proposalId: state.pathParameters['id'] ?? '',
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
                builder: (context, state) => const ProfileScreen(),
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
                    const VetReviewsListScreen(),
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
                    const VetCertificatesListScreen(),
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
                    const VetProfileScreen(),
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
                routes: [
                  GoRoute(
                    path: 'pending-approvals',
                    name: RouteNames.adminPendingApprovals,
                    builder: (context, state) =>
                        const AdminProposalReviewScreen(),
                  ),
                ],
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
                    const AdminProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // -------------------------------------------------------------------
      // Scan routes (accessible to all authenticated roles)
      // -------------------------------------------------------------------
      GoRoute(
        path: '/scan/muzzle-identify',
        builder: (context, state) => const StandaloneIdentifyScreen(),
      ),
      GoRoute(
        path: '/scan/muzzle/:animalId',
        name: RouteNames.muzzleCapture,
        builder: (context, state) => NativeMuzzleCameraScreen(
          species: state.uri.queryParameters['species'] ?? 'cow',
        ),
      ),
      GoRoute(
        path: '/scan/muzzle/identify/:animalId',
        name: RouteNames.muzzleIdentify,
        builder: (context, state) => NativeMuzzleCameraScreen(
          species: state.uri.queryParameters['species'] ?? 'cow',
        ),
      ),
      GoRoute(
        path: '/scan/muzzle/result',
        name: RouteNames.muzzleResult,
        builder: (context, state) => const MuzzleResultScreen(),
      ),
      GoRoute(
        path: '/scan/health/:animalId',
        name: RouteNames.healthCapture,
        builder: (context, state) => HealthCaptureScreen(
          animalId: state.pathParameters['animalId'] ?? '',
          species: _parseSpecies(state.uri.queryParameters['species']),
          sex: _parseSex(state.uri.queryParameters['sex']),
        ),
      ),
      GoRoute(
        path: '/scan/health/result',
        name: RouteNames.healthResult,
        builder: (context, state) => const HealthResultScreen(),
      ),

      // 360° guided photo capture route
      GoRoute(
        path: '/scan/photos/:animalId',
        name: 'guided-photo-capture',
        builder: (context, state) => GuidedPhotoCaptureScreen(
          animalName: state.uri.queryParameters['name'] ?? 'Animal',
        ),
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
      bottomNavigationBar: _CattleShieldNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: const [
          _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
          _NavItem(icon: Icons.pets_outlined, activeIcon: Icons.pets, label: 'Animals'),
          _NavItem(icon: Icons.track_changes_outlined, activeIcon: Icons.track_changes, label: 'Proposals'),
          _NavItem(icon: Icons.policy_outlined, activeIcon: Icons.policy, label: 'Policies'),
          _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
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
      bottomNavigationBar: _CattleShieldNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: const [
          _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard'),
          _NavItem(icon: Icons.rate_review_outlined, activeIcon: Icons.rate_review, label: 'Reviews'),
          _NavItem(icon: Icons.description_outlined, activeIcon: Icons.description, label: 'Certificates'),
          _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
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
      bottomNavigationBar: _CattleShieldNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: const [
          _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard'),
          _NavItem(icon: Icons.history_outlined, activeIcon: Icons.history, label: 'Audit Trail'),
          _NavItem(icon: Icons.warning_amber_outlined, activeIcon: Icons.warning_amber, label: 'Fraud Alerts'),
          _NavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CattleShield branded bottom navigation bar
// ---------------------------------------------------------------------------

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _CattleShieldNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_NavItem> items;

  const _CattleShieldNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isActive = index == currentIndex;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          isActive ? item.activeIcon : item.icon,
                          color: isActive
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w400,
                          color: isActive
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholder screen for routes whose real screens haven't been built yet
// ---------------------------------------------------------------------------

// Helper functions for parsing query parameters
AnimalSpecies _parseSpecies(String? s) {
  switch (s?.toLowerCase()) {
    case 'buffalo':
      return AnimalSpecies.buffalo;
    case 'mule':
      return AnimalSpecies.mule;
    case 'horse':
      return AnimalSpecies.horse;
    case 'donkey':
      return AnimalSpecies.donkey;
    default:
      return AnimalSpecies.cow;
  }
}

AnimalSex? _parseSex(String? s) {
  switch (s?.toLowerCase()) {
    case 'male':
      return AnimalSex.male;
    case 'female':
      return AnimalSex.female;
    default:
      return null;
  }
}

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

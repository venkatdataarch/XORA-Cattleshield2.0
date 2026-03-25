/// Centralised route name constants used by [GoRouter] named routes.
///
/// Using named routes avoids magic strings scattered across the codebase
/// and makes refactoring safer.
class RouteNames {
  RouteNames._();

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------
  static const splash = 'splash';
  static const login = 'login';
  static const otpVerification = 'otp-verification';
  static const farmerRegistration = 'farmer-registration';

  // ---------------------------------------------------------------------------
  // Farmer
  // ---------------------------------------------------------------------------
  static const farmerDashboard = 'farmer-dashboard';
  static const animalList = 'animal-list';
  static const animalOnboarding = 'animal-onboarding';
  static const animalDetail = 'animal-detail';

  static const proposalList = 'proposal-list';
  static const proposalForm = 'proposal-form';
  static const proposalDetail = 'proposal-detail';

  static const claimList = 'claim-list';
  static const claimForm = 'claim-form';
  static const claimDetail = 'claim-detail';
  static const claimEvidence = 'claim-evidence';

  static const policyList = 'policy-list';
  static const policyDetail = 'policy-detail';

  // ---------------------------------------------------------------------------
  // Vet
  // ---------------------------------------------------------------------------
  static const vetDashboard = 'vet-dashboard';
  static const vetProposalReview = 'vet-proposal-review';
  static const vetClaimReview = 'vet-claim-review';
  static const certificateForm = 'certificate-form';
  static const certificatePreview = 'certificate-preview';

  // ---------------------------------------------------------------------------
  // Scanning
  // ---------------------------------------------------------------------------
  static const muzzleCapture = 'muzzle-capture';
  static const muzzleResult = 'muzzle-result';
  static const muzzleIdentify = 'muzzle-identify';
  static const healthCapture = 'health-capture';
  static const healthResult = 'health-result';

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------
  static const profile = 'profile';
}

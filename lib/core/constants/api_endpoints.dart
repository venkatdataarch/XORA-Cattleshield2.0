class ApiEndpoints {
  ApiEndpoints._();

  // For Chrome/Web: use localhost
  // For Android emulator: use 10.0.2.2
  // For real device: use your PC's local IP (e.g., 192.168.x.x)
  // ngrok public URL for external access; change to localhost:8000 for local dev
  static const String baseUrl = 'https://restrictive-ernesto-polyphonically.ngrok-free.dev/api';

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String verifyOtp = '/auth/verify-otp';
  static const String currentUser = '/auth/me';

  // Dashboard
  static const String dashboardStats = '/dashboard/stats';

  // Form Schemas
  static String formSchema(String type) => '/form-schema/$type';

  // Animals
  static const String animals = '/animals';
  static String animalById(String id) => '/animals/$id';
  static String muzzleScan(String id) => '/animals/$id/muzzle-scan';

  // Cattle (legacy endpoints)
  static const String cattleRegister = '/cattle/register';
  static const String cattleIdentify = '/cattle/identify';
  static const String cattleAll = '/cattle';
  static String cattleById(String id) => '/cattle/$id';
  static String cattleByUcid(String ucid) => '/cattle/ucid/$ucid';
  static String cattleHealthScan(String id) => '/cattle/$id/health-scan';
  static String cattleHealthHistory(String id) => '/cattle/$id/health-history';

  // Mule (legacy endpoints)
  static const String muleRegister = '/mule/register';
  static const String muleIdentify = '/mule/identify';
  static const String muleAll = '/mule';
  static String muleById(String id) => '/mule/$id';
  static String muleByMuid(String muid) => '/mule/muid/$muid';
  static String muleHealthScan(String id) => '/mule/$id/health-scan';
  static String muleHealthHistory(String id) => '/mule/$id/health-history';
  static const String muleStats = '/mule/stats';

  // Farmers
  static const String farmers = '/farmers';
  static String farmerById(String id) => '/farmers/$id';

  // Mule Owners
  static const String muleOwners = '/mule/owners';
  static String muleOwnerById(String id) => '/mule/owners/$id';

  // Proposals
  static const String proposals = '/proposals';
  static String proposalById(String id) => '/proposals/$id';
  static String proposalVetDecision(String id) =>
      '/proposals/$id/vet-decision';

  // Policies
  static const String policies = '/policies';
  static String policyById(String id) => '/policies/$id';

  // Claims
  static const String claims = '/claims';
  static String claimById(String id) => '/claims/$id';
  static String claimMuzzleVerify(String id) => '/claims/$id/muzzle-verify';
  static String claimVetDecision(String id) => '/claims/$id/vet-decision';

  // Vet
  static const String vetPending = '/vet/pending';
  static const String vetCertificates = '/vet-certificates';

  // AI
  static String healthScore(String animalId) =>
      '/ai/health-score/$animalId';

  // Search
  static const String search = '/search';
}

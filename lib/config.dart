/// Build-time settings, passed with --dart-define (see README).
abstract final class AppConfig {
  /// The API base URL, ending in /api/v1. The default reaches a dev server on the host
  /// machine from the Android emulator.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  /// "dev", "staging" or "prod". Shown on non-production builds so nobody confuses them.
  static const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');

  static bool get isProduction => flavor == 'prod';

  /// The fingerprint (SHA-256 of the DER) of the first platform signing key, built into
  /// the app. The phone trusts only keys chained from it. Empty on dev builds: the phone
  /// then pins the first key it sees and refuses any change not endorsed by it.
  static const platformKeyFingerprint = String.fromEnvironment('PLATFORM_KEY_FP');
}

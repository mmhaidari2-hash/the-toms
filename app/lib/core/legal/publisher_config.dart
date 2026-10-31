/// Single place for publisher identity used by Privacy, Terms, Play listing copy and SECURITY contacts.
/// Fill every `[PLACEHOLDER: …]` before paid launch. Do not commit real secrets here.
class PublisherConfig {
  static const String productName = 'New Life UK';
  static const String businessName = '[PLACEHOLDER: BUSINESS LEGAL NAME]';
  static const String postalAddressUk = '[PLACEHOLDER: UK POSTAL ADDRESS]';
  static const String privacyEmail = '[PLACEHOLDER: PRIVACY CONTACT EMAIL]';
  static const String supportEmail = '[PLACEHOLDER: SUPPORT EMAIL]';
  static const String playContactEmail = '[PLACEHOLDER: PLAY LISTING CONTACT EMAIL]';
  static const String companyNumber = '[PLACEHOLDER: COMPANIES HOUSE NUMBER OR "sole trader"]';
  static const String icoRegistration = '[PLACEHOLDER: ICO REGISTRATION NUMBER IF REQUIRED, OR "not required / applying"]';
  /// Public HTTPS URL for web privacy / data-deletion info (Play Console external deletion field).
  /// Until a custom domain exists, the in-app Legal screen is the source of truth; set this when live.
  static const String publicPrivacyUrl = '[PLACEHOLDER: https://YOUR-DOMAIN/privacy]';
  static const String publicTermsUrl = '[PLACEHOLDER: https://YOUR-DOMAIN/terms]';
  static const String dataDeletionUrl = '[PLACEHOLDER: https://YOUR-DOMAIN/delete-data]';
  static const String securityContactEmail = '[PLACEHOLDER: SECURITY CONTACT EMAIL]';

  static bool get placeholdersRemaining =>
      businessName.contains('PLACEHOLDER') ||
      postalAddressUk.contains('PLACEHOLDER') ||
      privacyEmail.contains('PLACEHOLDER');
}

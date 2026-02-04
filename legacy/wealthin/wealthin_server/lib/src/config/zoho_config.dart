import 'dart:io';

class ZohoConfig {
  static String get clientId => Platform.environment['ZOHO_CLIENT_ID'] ?? '';
  static String get clientSecret => Platform.environment['ZOHO_CLIENT_SECRET'] ?? '';
  static String get refreshToken => Platform.environment['ZOHO_REFRESH_TOKEN'] ?? '';
  // Updated with correct project ID from API docs
  static String get projectId => Platform.environment['ZOHO_PROJECT_ID'] ?? '24392000000011167';
  // Updated with correct org ID from API docs
  static String get orgId => Platform.environment['ZOHO_CATALYST_ORG_ID'] ?? '60056122667';

  static bool get isValid =>
      clientId.isNotEmpty &&
      clientSecret.isNotEmpty &&
      refreshToken.isNotEmpty;
}

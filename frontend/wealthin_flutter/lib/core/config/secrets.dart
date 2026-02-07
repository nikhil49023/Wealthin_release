/// Application Secrets & API Keys
/// 
/// SECURITY WARNING: This file contains sensitive API keys.
/// - DO NOT commit this file to version control
/// - Add this file to .gitignore
/// - In production, use environment variables or secure storage
/// 
/// For production deployment:
/// 1. Use --dart-define for compile-time injection
/// 2. Or use flutter_secure_storage with encrypted preferences
/// 3. Or use dart-define-from-file with a local secrets.json
class AppSecrets {
  // Sarvam AI API Key - for AI chat and document processing
  // Get your key at: https://dashboard.sarvam.ai
  static const String sarvamApiKey = String.fromEnvironment(
    'SARVAM_API_KEY',
    defaultValue: "sk_vqh8cfif_MWrqmgK4dyzLoIOqxJn8udIc",
  );
  
  // ScrapingDog API Key - for web search functionality
  // Get your key at: https://www.scrapingdog.com
  static const String scrapingDogApiKey = String.fromEnvironment(
    'SCRAPINGDOG_API_KEY', 
    defaultValue: "69414673ebeb2d23522c1f04",
  );
  
  // Zoho Project configuration (for task/project management)
  static const Map<String, String> zohoConfig = {
    "project_id": "24392000000011167", 
    "org_id": "60056122667",
    "client_id": "1000.S502C4RR4OX00EXMKPMKP246HJ9LYY",
  };
  
  /// Check if using default/development keys
  static bool get isUsingDefaultKeys => 
      sarvamApiKey.contains("sk_vqh8cfif") || 
      scrapingDogApiKey == "69414673ebeb2d23522c1f04";
}

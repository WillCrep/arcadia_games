class ApiConfig {
  // Reemplaza por tu URL de Azure Functions / Static Web App
  static const String baseUrl = 'https://jolly-mud-018639f0f.7.azurestaticapps.net/api';
  
  // Timeout
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 25);
}
/// Typed HTTP errors surfaced to the UI layer.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// 401 — the token is missing, invalid, or expired. The app treats this as
/// "logged out" and returns to the login screen.
class AuthExpiredException extends ApiException {
  AuthExpiredException(super.message) : super(401);
}

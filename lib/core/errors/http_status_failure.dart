/// Implemented by typed HTTP clients so the shared failure mapper can tell a
/// backend outage (5xx) from a lost connection or a bad request.
///
/// A 503 from the Worker means the service answered and failed. Calling that
/// "check your connection" sends users to their Wi-Fi settings for a problem
/// that lives on the server.
abstract interface class HttpStatusFailure {
  int get statusCode;
  String get message;
}

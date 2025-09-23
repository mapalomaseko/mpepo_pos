import 'package:http/http.dart' as http;

/// Simple factory so the http client can be mocked in tests.
class HttpClientFactory {
  static http.Client create() => http.Client();
}

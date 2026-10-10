import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// An error from the backend ({ error: { code, message, details } }) or the network.
class ApiException implements Exception {
  final int status; // 0 = no response (offline, timeout)
  final String code;
  final String message;
  final Object? details;
  const ApiException(this.status, this.code, this.message, [this.details]);

  @override
  String toString() => message;
}

const _defaultBase = 'http://localhost:4010/api/v1';

/// API_BASE_URL from .env. The Android emulator cannot reach the host as "localhost",
/// so it is rewritten to 10.0.2.2 there.
String get apiBase {
  var b = (dotenv.isInitialized ? dotenv.maybeGet('API_BASE_URL') : null) ?? _defaultBase;
  if (Platform.isAndroid) {
    b = b.replaceFirst('//localhost', '//10.0.2.2').replaceFirst('//127.0.0.1', '//10.0.2.2');
  }
  return b.endsWith('/') ? b.substring(0, b.length - 1) : b;
}

/// HTTP client for the Kharcha backend. Keeps the tokens in secure storage and
/// refreshes the access token on a 401 (once, shared by parallel requests).
class Api {
  static const _store = FlutterSecureStorage();
  String? _access;
  String? _refresh;
  Future<bool>? _refreshing;

  /// Called when the refresh token is rejected: the user has to sign in again.
  void Function()? onSignedOut;

  bool get hasSession => _refresh != null;
  String? get refreshToken => _refresh;

  Future<void> load() async {
    try {
      _access = await _store.read(key: 'access');
      _refresh = await _store.read(key: 'refresh');
    } catch (_) {} // keychain unavailable: start signed out
  }

  Future<void> setTokens(String access, String refresh) async {
    _access = access;
    _refresh = refresh;
    try {
      await _store.write(key: 'access', value: access);
      await _store.write(key: 'refresh', value: refresh);
    } catch (_) {} // still works for this run
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    try {
      await _store.delete(key: 'access');
      await _store.delete(key: 'refresh');
    } catch (_) {}
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final u = Uri.parse('$apiBase$path');
    return query == null || query.isEmpty ? u : u.replace(queryParameters: query);
  }

  Future<http.Response> _send(http.BaseRequest Function() build, {required bool auth}) async {
    Future<http.Response> once() async {
      final r = build();
      if (auth && _access != null) r.headers['authorization'] = 'Bearer $_access';
      try {
        final streamed = await r.send().timeout(const Duration(seconds: 90));
        return await http.Response.fromStream(streamed);
      } on SocketException {
        throw const ApiException(0, 'NETWORK', 'Cannot reach the server. Check your connection.');
      } on http.ClientException {
        throw const ApiException(0, 'NETWORK', 'Cannot reach the server. Check your connection.');
      } on TimeoutException {
        throw const ApiException(0, 'TIMEOUT', 'The server took too long to answer.');
      }
    }

    var res = await once();
    if (auth && res.statusCode == 401 && _refresh != null && await _refreshTokens()) {
      res = await once();
    }
    return res;
  }

  Future<bool> _refreshTokens() async {
    final f = _refreshing ??= _doRefresh();
    try {
      return await f;
    } finally {
      _refreshing = null;
    }
  }

  Future<bool> _doRefresh() async {
    try {
      final res = await http
          .post(_uri('/auth/refresh'),
              headers: {'content-type': 'application/json'},
              body: jsonEncode({'refreshToken': _refresh}))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        await setTokens(j['accessToken'] as String, j['refreshToken'] as String);
        return true;
      }
      if (res.statusCode == 401) {
        await clear();
        onSignedOut?.call();
      }
    } catch (_) {} // offline: keep the session, try again later
    return false;
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isEmpty ? null : jsonDecode(res.body);
    }
    try {
      final e = (jsonDecode(res.body) as Map<String, dynamic>)['error'] as Map<String, dynamic>;
      throw ApiException(res.statusCode, e['code'] as String? ?? 'ERROR',
          e['message'] as String? ?? 'Something went wrong', e['details']);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(res.statusCode, 'ERROR', 'Something went wrong (${res.statusCode})');
    }
  }

  Future<dynamic> request(String method, String path,
      {Map<String, String>? query, Object? body, bool auth = true}) async {
    final res = await _send(() {
      final r = http.Request(method, _uri(path, query));
      if (body != null) {
        r.headers['content-type'] = 'application/json';
        r.body = jsonEncode(body);
      }
      return r;
    }, auth: auth);
    return _decode(res);
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      request('GET', path, query: query);
  Future<dynamic> post(String path, {Object? body, bool auth = true}) =>
      request('POST', path, body: body, auth: auth);
  Future<dynamic> patch(String path, {Object? body}) => request('PATCH', path, body: body);
  Future<dynamic> put(String path, {Object? body}) => request('PUT', path, body: body);
  Future<dynamic> delete(String path, {Object? body}) => request('DELETE', path, body: body);

  /// multipart/form-data with one file.
  Future<dynamic> upload(String method, String path,
      {required String field,
      required Uint8List bytes,
      required String filename,
      Map<String, String> fields = const {}}) async {
    final res = await _send(() {
      final r = http.MultipartRequest(method, _uri(path))..fields.addAll(fields);
      r.files.add(http.MultipartFile.fromBytes(field, bytes, filename: filename));
      return r;
    }, auth: true);
    return _decode(res);
  }

  /// Raw bytes of a protected file (profile photo).
  Future<Uint8List> bytes(String path) async {
    final res = await _send(() => http.Request('GET', _uri(path)), auth: true);
    if (res.statusCode < 200 || res.statusCode >= 300) _decode(res); // throws
    return res.bodyBytes;
  }
}

final api = Api();

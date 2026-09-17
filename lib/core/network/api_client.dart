import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../data/repositories/repositories.dart' show AppException;
import 'api_config.dart';

//==============================================================================
// SPOCART — HTTP client
//------------------------------------------------------------------------------
// Attaches the bearer token, unwraps the API envelope ({ ok, data } /
// { ok:false, message }) and turns every failure into an AppException with a
// message that is safe to show in a snackbar. Repositories never touch http.
//==============================================================================

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  /// Bearer token attached to every request; null when signed out.
  String? token;

  /// Called when the server says the session is no longer valid (401).
  void Function()? onUnauthorized;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl$path').replace(queryParameters: query);

  Map<String, String> _headers({bool json = true}) => <String, String>{
        'accept': 'application/json',
        if (json) 'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      };

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send(() => _client.get(_uri(path, query), headers: _headers(json: false)));

  Future<dynamic> post(String path, [Object? body]) => _send(() =>
      _client.post(_uri(path), headers: _headers(), body: jsonEncode(body ?? {})));

  Future<dynamic> put(String path, [Object? body]) => _send(() =>
      _client.put(_uri(path), headers: _headers(), body: jsonEncode(body ?? {})));

  Future<dynamic> patch(String path, [Object? body]) => _send(() =>
      _client.patch(_uri(path), headers: _headers(), body: jsonEncode(body ?? {})));

  Future<dynamic> delete(String path) =>
      _send(() => _client.delete(_uri(path), headers: _headers(json: false)));

  /// Multipart upload of one file under [field].
  Future<dynamic> upload(String path, {required String field, required String filePath, String? fileName}) {
    return _send(() async {
      final http.MultipartRequest req = http.MultipartRequest('POST', _uri(path));
      req.headers.addAll(_headers(json: false));
      req.files.add(await http.MultipartFile.fromPath(field, filePath, filename: fileName));
      final http.StreamedResponse streamed = await req.send().timeout(ApiConfig.timeout);
      return http.Response.fromStream(streamed);
    });
  }

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request().timeout(ApiConfig.timeout);
    } on SocketException {
      throw const AppException('No internet connection. Please check your network and try again.');
    } on TimeoutException {
      throw const AppException('The server is taking too long to respond. Please try again.');
    } on http.ClientException {
      throw const AppException('Could not reach SPOCART. Please try again.');
    }

    Map<String, dynamic>? body;
    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } on FormatException {
      body = null;
    }

    if (response.statusCode == 401) {
      onUnauthorized?.call();
      throw AppException(body?['message'] as String? ?? 'Your session has expired. Please sign in again.');
    }
    if (body == null) {
      throw const AppException('Unexpected response from the server. Please try again.');
    }
    if (body['ok'] != true) {
      throw AppException(body['message'] as String? ?? 'Something went wrong. Please try again.');
    }
    return body['data'];
  }

  void close() => _client.close();
}

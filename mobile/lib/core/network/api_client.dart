import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;
import '../config/app_config.dart';
import '../utils/error_messages.dart';
import '../../data/models/profile_model.dart';
import '../../data/models/warranty_model.dart';

class ApiClient {
  final String? accessToken;
  static final http.Client _client = http.Client();
  static const Duration _timeout = Duration(seconds: 15);
  static const Duration _ocrTimeout = Duration(seconds: 45);

  ApiClient({this.accessToken});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  static MediaType _imageMediaType(String filePath) {
    switch (p.extension(filePath).toLowerCase()) {
      case '.png':
        return MediaType('image', 'png');
      case '.webp':
        return MediaType('image', 'webp');
      case '.heic':
        return MediaType('image', 'heic');
      case '.heif':
        return MediaType('image', 'heif');
      case '.jpg':
      case '.jpeg':
      default:
        return MediaType('image', 'jpeg');
    }
  }

  Future<Map<String, dynamic>> scanReceipt({
    required String receiptPath,
    String? serialPath,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/ocr/scan');
    final request = http.MultipartRequest('POST', uri);

    if (accessToken != null) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        'receipt',
        receiptPath,
        contentType: _imageMediaType(receiptPath),
      ),
    );
    if (serialPath != null && serialPath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'serial',
          serialPath,
          contentType: _imageMediaType(serialPath),
        ),
      );
    }

    final streamedResponse = await request.send().timeout(_ocrTimeout);
    final response = await http.Response.fromStream(streamedResponse).timeout(_ocrTimeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw ApiException.fromStatus(
        response.statusCode,
        fallback: "Couldn't scan that receipt. You can enter the details manually.",
      );
    }
  }

  Future<Map<String, dynamic>> uploadImages({
    required String receiptPath,
    String? serialPath,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/warranties/upload-images');
    final request = http.MultipartRequest('POST', uri);

    if (accessToken != null) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        'receipt',
        receiptPath,
        contentType: _imageMediaType(receiptPath),
      ),
    );
    if (serialPath != null && serialPath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'serial',
          serialPath,
          contentType: _imageMediaType(serialPath),
        ),
      );
    }

    final streamedResponse = await request.send().timeout(_ocrTimeout);
    final response = await http.Response.fromStream(streamedResponse).timeout(_ocrTimeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw ApiException.fromStatus(
        response.statusCode,
        fallback: "Couldn't upload your receipt photo. Please try again.",
      );
    }
  }

  Future<void> discardUploads({
    String? receiptPath,
    String? serialPath,
  }) async {
    if ((receiptPath == null || receiptPath.isEmpty) &&
        (serialPath == null || serialPath.isEmpty)) {
      return;
    }
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/ocr/discard');
    await _client
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({
            'receipt_path': receiptPath,
            'serial_path': serialPath,
          }),
        )
        .timeout(_timeout);
  }

  Future<List<WarrantyModel>> getWarranties({String? query, String? category}) async {
    final params = <String, String>{};
    if (query != null && query.isNotEmpty) params['q'] = query;
    if (category != null && category.isNotEmpty) params['category'] = category;

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/warranties').replace(queryParameters: params);
    final response = await _client.get(uri, headers: _headers).timeout(_timeout);

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((item) => WarrantyModel.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      throw ApiException.fromStatus(
        response.statusCode,
        fallback: "Couldn't load your warranties right now.",
      );
    }
  }

  Future<WarrantyModel> createWarranty(WarrantyModel warranty) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/warranties');
    final response = await _client
        .post(
          uri,
          headers: _headers,
          body: jsonEncode(warranty.toJson()),
        )
        .timeout(_timeout);

    if (response.statusCode == 201) {
      return WarrantyModel.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException.fromStatus(
        response.statusCode,
        fallback: "Couldn't save this warranty. Please try again.",
      );
    }
  }

  Future<WarrantyModel> updateWarranty(String id, Map<String, dynamic> patch) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/warranties/$id');
    final response = await _client
        .patch(
          uri,
          headers: _headers,
          body: jsonEncode(patch),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return WarrantyModel.fromJson(jsonDecode(response.body));
    } else {
      throw ApiException.fromStatus(
        response.statusCode,
        fallback: "Couldn't save your changes. Please try again.",
      );
    }
  }

  Future<void> deleteWarranty(String id) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/warranties/$id');
    final response = await _client.delete(uri, headers: _headers).timeout(_timeout);

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw ApiException.fromStatus(
        response.statusCode,
        fallback: "Couldn't delete this warranty. Please try again.",
      );
    }
  }

  Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/health');
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<UserProfile> getProfile() async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/profile');
    final response = await _client.get(uri, headers: _headers).timeout(_timeout);

    if (response.statusCode == 200) {
      return UserProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw ApiException.fromStatus(
        response.statusCode,
        fallback: "Couldn't load your profile right now.",
      );
    }
  }

  Future<UserProfile> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/profile');
    final payload = <String, dynamic>{};
    if (fullName != null) payload['full_name'] = fullName;
    if (phone != null) payload['phone'] = phone;
    if (avatarUrl != null) payload['avatar_url'] = avatarUrl;

    final response = await _client
        .patch(uri, headers: _headers, body: jsonEncode(payload))
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return UserProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw ApiException.fromStatus(
        response.statusCode,
        fallback: "Couldn't update your profile right now.",
      );
    }
  }

  Future<UserProfile> uploadAvatar(String filePath) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/profile/avatar');
    final request = http.MultipartRequest('POST', uri);

    if (accessToken != null) {
      request.headers['Authorization'] = 'Bearer $accessToken';
    }
    request.files.add(
      await http.MultipartFile.fromPath(
        'avatar',
        filePath,
        contentType: _imageMediaType(filePath),
      ),
    );

    final streamedResponse = await request.send().timeout(_ocrTimeout);
    final response = await http.Response.fromStream(streamedResponse).timeout(_ocrTimeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return UserProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } else {
      throw ApiException.fromStatus(
        response.statusCode,
        fallback: "Couldn't upload your profile photo. Please try again.",
      );
    }
  }
}

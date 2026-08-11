import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/remove_background_result.dart';

class BackgroundRemovalException implements Exception {
  const BackgroundRemovalException(this.message);
  final String message;
}

/// Kept separate from UI so an owned serverless proxy can be used if FileConv
/// does not permit CORS from the deployed public site.
class RemoveBackgroundService {
  RemoveBackgroundService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  /// Only set this at build time for an owned, privacy-preserving CORS proxy.
  static const String fileConvProxyBaseUrl = String.fromEnvironment('FILECONV_PROXY_BASE');
  /// Debug web runs use the local proxy. A release build always uses the
  /// same-origin Pages Function, so it has no localhost dependency.
  String get _base {
    if (fileConvProxyBaseUrl.isNotEmpty) return _withoutTrailingSlashes(fileConvProxyBaseUrl);
    if (kDebugMode) return 'http://localhost:8788/fileconv';
    return '/fileconv';
  }

  String _withoutTrailingSlashes(String value) => value.replaceFirst(RegExp(r'/+$'), '');

  Future<_UploadResponse> _uploadBrowserForm(Uint8List bytes, String filename) async {
    final form = html.FormData()
      ..appendBlob('file', html.Blob(<dynamic>[bytes], _imageMimeType(filename)), filename);
    final request = html.HttpRequest()..open('POST', '$_base/api/remove-bg/upload');
    request.send(form);
    await request.onLoadEnd.first.timeout(const Duration(seconds: 45));
    return _UploadResponse(request.status ?? 0, request.responseText ?? '');
  }

  Future<RemoveBackgroundResult> remove({required Uint8List bytes, required String filename}) async {
    try {
      final upload = await _uploadBrowserForm(bytes, filename);
      if (upload.statusCode < 200 || upload.statusCode >= 300) {
        throw BackgroundRemovalException(_responseMessage(upload.statusCode, upload.body, 'ပုံတင်၍ နောက်ခံဖယ်ရှားမရပါ။'));
      }
      final decoded = _jsonObject(upload.body);
      final jobId = decoded['jobId']?.toString();
      if (jobId == null || jobId.isEmpty) {
        throw const BackgroundRemovalException('ဝန်ဆောင်မှုမှ မမှန်ကန်သော အဖြေ ရရှိပါသည်။');
      }
      final uuid = await _poll(jobId);
      return RemoveBackgroundResult(uuid: uuid);
    } on BackgroundRemovalException {
      rethrow;
    } on TimeoutException {
      throw const BackgroundRemovalException('နောက်ခံဖယ်ရှားချိန် ကြာမြင့်နေပါသည်။ နောက်မှ ထပ်ကြိုးစားပါ။');
    } on http.ClientException catch (e) {
      throw BackgroundRemovalException('FileConv ကို မချိတ်ဆက်နိုင်ပါ။ Local run တွင် local proxy ကို စတင်ထားပါ။ (${e.message})');
    } catch (_) {
      throw const BackgroundRemovalException('နောက်ခံဖယ်ရှားရာတွင် အခက်အခဲရှိပါသည်။');
    }
  }

  Future<String> _poll(String jobId) async {
    for (var attempt = 0; attempt < 60; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final response = await _client.get(Uri.parse('$_base/api/remove-bg/status?jobId=${Uri.encodeQueryComponent(jobId)}')).timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw BackgroundRemovalException(_responseMessage(response.statusCode, response.body, 'လုပ်ဆောင်မှုအခြေအနေကို မရယူနိုင်ပါ။'));
      }
      final status = _jsonObject(response.body);
      if (status['status'] == 'completed') {
        final result = status['result'];
        if (result is Map && result['success'] == true && result['uuid'] != null) return result['uuid'].toString();
        throw const BackgroundRemovalException('နောက်ခံဖယ်ရှားမရပါ။');
      }
      if (status['status'] == 'failed' || status['error'] != null) {
        throw const BackgroundRemovalException('နောက်ခံဖယ်ရှားမရပါ။ ခဏအကြာတွင် ထပ်ကြိုးစားပါ။');
      }
    }
    throw const BackgroundRemovalException('နောက်ခံဖယ်ရှားချိန် ကြာမြင့်နေပါသည်။ နောက်မှ ထပ်ကြိုးစားပါ။');
  }

  Uri downloadUri(String uuid) => Uri.parse('$_base/api/remove-bg/download?uuid=${Uri.encodeQueryComponent(uuid)}');

  Future<Uint8List> download(String uuid) async {
    try {
      final response = await _client.get(downloadUri(uuid)).timeout(const Duration(seconds: 45));
      if (response.statusCode < 200 || response.statusCode >= 300 || response.bodyBytes.isEmpty) {
        throw BackgroundRemovalException(_responseMessage(response.statusCode, response.body, 'နောက်ခံဖယ်ရှားပြီးပုံကို မရယူနိုင်ပါ။'));
      }
      return response.bodyBytes;
    } on BackgroundRemovalException { rethrow; }
      on TimeoutException { throw const BackgroundRemovalException('ပုံရယူချိန် ကြာမြင့်နေပါသည်။'); }
      on http.ClientException catch (e) { throw BackgroundRemovalException('FileConv မှ ပုံကို မရယူနိုင်ပါ။ (${e.message})'); }
      catch (_) { throw const BackgroundRemovalException('ပုံရယူရာတွင် အခက်အခဲရှိပါသည်။'); }
  }

  Map<String, dynamic> _jsonObject(String value) {
    // Avoids a hidden dynamic HTTP contract: only decoded object maps are accepted.
    final decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const BackgroundRemovalException('ဝန်ဆောင်မှုမှ မမှန်ကန်သော အဖြေ ရရှိပါသည်။');
  }

  String _responseMessage(int statusCode, String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final detail = decoded['error'] ?? decoded['message'];
        if (detail is String && detail.isNotEmpty) return '$fallback (FileConv: $detail)';
      }
    } catch (_) {}
    return '$fallback (FileConv HTTP $statusCode)';
  }

  String _imageMimeType(String filename) {
    switch (filename.toLowerCase().split('.').last) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        throw const BackgroundRemovalException('JPG၊ JPEG သို့မဟုတ် PNG ပုံဖိုင်ကိုသာ အသုံးပြုပါ။');
    }
  }
}

class _UploadResponse {
  const _UploadResponse(this.statusCode, this.body);
  final int statusCode;
  final String body;
}

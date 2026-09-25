import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Thrown on any non-2xx response. Mirrors ApiError in apps/web/lib/api.ts.
class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, this.status);

  @override
  String toString() => message;
}

class RegistrationResult {
  const RegistrationResult(
      {this.accessToken, this.onboardingToken, required this.accountStatus});
  final String? accessToken;
  final String? onboardingToken;
  final String accountStatus;
}

class PaymentInstructions {
  const PaymentInstructions(
      {required this.amount,
      required this.currency,
      required this.upiId,
      required this.qrUrl,
      required this.supportEmail});
  final String amount;
  final String currency;
  final String upiId;
  final String qrUrl;
  final String supportEmail;
}

/// Mirrors apps/web/lib/api.ts — same base URL convention, same endpoints,
/// same bearer-token auth. Point `baseUrl` at the same FastAPI workspace the
/// web app talks to.
///
/// Defaults to the iOS simulator's host-loopback address. Override with
/// `--dart-define=API_BASE_URL=http://<mac-ip>:8000/api/v1` for a real iPhone
/// connected to the same local network as the Mac.
class AevraApiClient {
  AevraApiClient({String? baseUrl})
      : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://localhost:8000/api/v1',
            );

  final String baseUrl;

  Uri _uri(String path) =>
      Uri.parse('$baseUrl${path.startsWith('/') ? path : '/$path'}');

  Future<T> _request<T>(
    String path, {
    String method = 'GET',
    String? token,
    Object? body,
    required T Function(dynamic json) parse,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final uri = _uri(path);
    late http.Response response;
    switch (method) {
      case 'PATCH':
        response = await http.patch(uri,
            headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      case 'POST':
        response = await http.post(uri,
            headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      default:
        response = await http.get(uri, headers: headers);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'The request could not be completed.';
      try {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final detail = payload['detail'];
        if (detail is String) {
          message = detail;
        } else if (detail is List) {
          message = detail
              .map((e) => (e as Map)['msg'])
              .where((e) => e != null)
              .join('. ');
        } else if (payload['error'] is Map &&
            payload['error']['message'] != null) {
          message = payload['error']['message'] as String;
        }
      } catch (_) {
        // Non-JSON error body — keep the default message.
      }
      throw ApiException(message, response.statusCode);
    }

    if (response.body.isEmpty) return parse(null);
    return parse(jsonDecode(response.body));
  }

  Future<String> login(String email, String password) => _request<String>(
        '/auth/login',
        method: 'POST',
        body: {'email': email, 'password': password},
        parse: (json) => json['access_token'] as String,
      );

  Future<RegistrationResult> register({
    required String email,
    required String password,
    required String displayName,
    required String organizationName,
    required String workspaceName,
    required String accountType,
    required String timezone,
  }) =>
      _request<RegistrationResult>(
        '/auth/register',
        method: 'POST',
        body: {
          'email': email,
          'password': password,
          'display_name': displayName,
          'organization_name': organizationName,
          'workspace_name': workspaceName,
          'account_type': accountType,
          'brand_name': organizationName,
          'timezone': timezone,
        },
        parse: (json) => RegistrationResult(
          accessToken: (json['token'] as Map<String, dynamic>?)?['access_token']
              as String?,
          onboardingToken: json['onboarding_token'] as String?,
          accountStatus: json['account_status'] as String? ?? 'pending_payment',
        ),
      );

  Future<AevraUser> me(String token) => _request<AevraUser>(
        '/auth/me',
        token: token,
        parse: (json) => AevraUser.fromJson(json as Map<String, dynamic>),
      );

  Future<PaymentInstructions> paymentInstructions() =>
      _request<PaymentInstructions>(
        '/auth/onboarding/payment-instructions',
        parse: (json) => PaymentInstructions(
          amount: json['amount'] as String? ?? '0',
          currency: json['currency'] as String? ?? 'INR',
          upiId: json['upi_id'] as String? ?? '',
          qrUrl: json['qr_url'] as String? ?? '',
          supportEmail: json['support_email'] as String? ?? '',
        ),
      );

  Future<void> submitPayment(String onboardingToken, String utr,
          {String? note}) =>
      _request<void>(
        '/auth/onboarding/payment-submissions/public',
        method: 'POST',
        body: {
          'onboarding_token': onboardingToken,
          'utr_reference': utr,
          if (note != null) 'note': note
        },
        parse: (_) {},
      );

  Future<List<Workspace>> workspaces(String token) => _request<List<Workspace>>(
        '/workspaces',
        token: token,
        parse: (json) => (json as List)
            .map((e) => Workspace.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<List<Brand>> brands(String token, String workspaceId) =>
      _request<List<Brand>>(
        '/workspaces/$workspaceId/brands',
        token: token,
        parse: (json) => (json as List)
            .map((e) => Brand.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<List<Campaign>> campaigns(String token, String workspaceId) =>
      _request<List<Campaign>>(
        '/workspaces/$workspaceId/campaigns',
        token: token,
        parse: (json) => (json as List)
            .map((e) => Campaign.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<List<ContentVariant>> variants(
          String token, String workspaceId, String campaignId) =>
      _request<List<ContentVariant>>(
        '/workspaces/$workspaceId/campaigns/$campaignId/variants',
        token: token,
        parse: (json) => (json as List)
            .map((e) => ContentVariant.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<Campaign> decideCampaign(
    String token,
    String workspaceId,
    String campaignId,
    String decision,
  ) =>
      _request<Campaign>(
        '/workspaces/$workspaceId/campaigns/$campaignId/decision',
        method: 'POST',
        token: token,
        body: {'decision': decision, 'feedback': null},
        parse: (json) => Campaign.fromJson(
            (json as Map<String, dynamic>)['campaign'] as Map<String, dynamic>),
      );

  Future<List<KnowledgeDocument>> documents(String token, String workspaceId) =>
      _request<List<KnowledgeDocument>>(
        '/workspaces/$workspaceId/knowledge/documents',
        token: token,
        parse: (json) => (json as List)
            .map((e) => KnowledgeDocument.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<List<MediaAsset>> media(String token, String workspaceId) =>
      _request<List<MediaAsset>>(
        '/workspaces/$workspaceId/media/assets',
        token: token,
        parse: (json) => (json as List)
            .map((e) => MediaAsset.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<List<MediaAsset>> generateImage(
          String token, String workspaceId, String prompt,
          {String aspectRatio = '1:1'}) =>
      _request<List<MediaAsset>>(
        '/workspaces/$workspaceId/media/images/generate',
        token: token,
        method: 'POST',
        body: {
          'campaign_id': null,
          'prompt': prompt,
          'platforms': ['instagram'],
          'aspect_ratio': aspectRatio,
          'brand_overlay': true,
          'brand_text': 'VAE',
        },
        parse: (json) => ((json as Map<String, dynamic>)['assets'] as List)
            .map((e) => MediaAsset.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<List<SocialAccount>> accounts(String token, String workspaceId) =>
      _request<List<SocialAccount>>(
        '/workspaces/$workspaceId/publishing/accounts',
        token: token,
        parse: (json) => (json as List)
            .map((e) => SocialAccount.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<List<ScheduledPost>> scheduled(String token, String workspaceId) =>
      _request<List<ScheduledPost>>(
        '/workspaces/$workspaceId/operations/schedule',
        token: token,
        parse: (json) => (json as List)
            .map((e) => ScheduledPost.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<MediaAsset?> pickAndUpload(String token, String workspaceId,
      {bool imagesOnly = false}) async {
    final selection = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: imagesOnly
            ? ['jpg', 'jpeg', 'png', 'webp']
            : ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'mov'],
        withData: true);
    if (selection == null) return null;
    final file = selection.files.single;
    if (file.bytes == null) {
      throw ApiException('Unable to read this file.', 400);
    }
    if (file.size > 50 * 1024 * 1024) {
      throw ApiException('Choose a file smaller than 50 MB.', 400);
    }
    final request = http.MultipartRequest(
        'POST', _uri('/workspaces/$workspaceId/media/assets/upload'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes('file', file.bytes!,
          filename: file.name,
          contentType: MediaType.parse(switch (file.extension?.toLowerCase()) {
            'png' => 'image/png',
            'webp' => 'image/webp',
            'mp4' => 'video/mp4',
            'mov' => 'video/quicktime',
            _ => 'image/jpeg'
          })));
    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode >= 300) {
      throw ApiException(
          'Upload failed. Please try again.', response.statusCode);
    }
    return MediaAsset.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AevraUser> updateProfile(String token, Map<String, dynamic> body) =>
      _request('/auth/me',
          method: 'PATCH',
          token: token,
          body: body,
          parse: (json) => AevraUser.fromJson(json as Map<String, dynamic>));
  Future<void> changePassword(String token, String current, String next) =>
      _request('/auth/change-password',
          method: 'POST',
          token: token,
          body: {'current_password': current, 'new_password': next},
          parse: (_) {});
  Future<Map<String, dynamic>> mlInsights(
          String token, String workspaceId, String draft, String platform) =>
      _request('/workspaces/$workspaceId/ml/insights',
          token: token,
          method: 'POST',
          body: {'draft': draft, 'platform': platform},
          parse: (json) => Map<String, dynamic>.from(json as Map));

  Future<List<PostMetric>> metrics(String token, String workspaceId) =>
      _request('/workspaces/$workspaceId/operations/metrics',
          token: token,
          parse: (json) => (json as List)
              .map((m) => PostMetric(m as Map<String, dynamic>))
              .toList());
  Future<Map<String, dynamic>> publish(
          String token, String workspaceId, Map<String, dynamic> payload,
          {bool schedule = false}) =>
      _request(
          '/workspaces/$workspaceId/${schedule ? 'operations/schedule' : 'publishing/jobs'}',
          token: token,
          method: 'POST',
          body: payload,
          parse: (json) => json as Map<String, dynamic>);
  Future<void> updateScheduled(
          String token, String workspaceId, String id, String action) =>
      _request('/workspaces/$workspaceId/operations/schedule/$id/$action',
          token: token, method: 'POST', parse: (_) {});
  Future<Map<String, dynamic>> adminOverview(String token) =>
      _request('/auth/admin/overview',
          token: token, parse: (json) => json as Map<String, dynamic>);

  Future<String> generateText(String token, String workspaceId, String prompt,
      void Function(String) onText) async {
    final client = http.Client();
    try {
      final request = http.Request(
          'POST', _uri('/workspaces/$workspaceId/models/local/generate/stream'))
        ..headers.addAll({
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        })
        ..body = jsonEncode({'prompt': prompt, 'max_tokens': 640});
      final response = await client.send(request);
      if (response.statusCode >= 300) {
        throw ApiException(
            'Text generation is unavailable. Try again.', response.statusCode);
      }
      var text = '';
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!line.startsWith('data: ')) continue;
        final value = line.substring(6).trim();
        if (value == '[DONE]') continue;
        final event = jsonDecode(value) as Map<String, dynamic>;
        if (event['message'] != null) {
          throw ApiException(event['message'].toString(), 500);
        }
        text += event['token'] as String? ?? '';
        onText(text);
      }
      return text;
    } finally {
      client.close();
    }
  }

  Future<String> authorizeChannel(
          String token, String workspaceId, String provider) =>
      _request('/workspaces/$workspaceId/publishing/oauth/$provider/authorize',
          token: token, parse: (json) => json['authorization_url'] as String);
  Future<void> disconnectChannel(
          String token, String workspaceId, SocialAccount account) =>
      _request(
          '/workspaces/$workspaceId/publishing/oauth/${account.platform}/accounts/${account.id}/revoke',
          token: token,
          method: 'POST',
          parse: (_) {});
  Future<List<Map<String, dynamic>>> adminPayments(String token) =>
      _request('/auth/admin/payment-submissions',
          token: token,
          parse: (json) => (json as List).cast<Map<String, dynamic>>());
  Future<void> reviewPayment(
          String token, String id, String decision, String note) =>
      _request('/auth/admin/payment-submissions/$id/$decision',
          token: token, method: 'POST', body: {'note': note}, parse: (_) {});

  Future<Brand> createBrand(
          String token, String workspaceId, String name, String description) =>
      _request('/workspaces/$workspaceId/brands',
          token: token,
          method: 'POST',
          body: {
            'name': name,
            'description': description,
            'website_url': null,
            'industry': null,
            'tone_attributes': ['clear', 'confident'],
            'target_audiences': [],
            'preferred_ctas': [],
            'preferred_hashtags': [],
            'status': 'active'
          },
          parse: (json) => Brand.fromJson(json as Map<String, dynamic>));

  Future<KnowledgeDocument> ingestSource(
          String token, String workspaceId, String title, String content,
          {String? brandId}) =>
      _request('/workspaces/$workspaceId/knowledge/documents',
          token: token,
          method: 'POST',
          body: {
            'title': title,
            'source_type': 'markdown',
            'content': content,
            'brand_id': brandId
          },
          parse: (json) => KnowledgeDocument.fromJson(
              json['document'] as Map<String, dynamic>));

  Future<List<Map<String, dynamic>>> searchKnowledge(
          String token, String workspaceId, String query, {String? brandId}) =>
      _request('/workspaces/$workspaceId/knowledge/search',
          token: token,
          method: 'POST',
          body: {'query': query, 'brand_id': brandId},
          parse: (json) =>
              (json['citations'] as List).cast<Map<String, dynamic>>());
}

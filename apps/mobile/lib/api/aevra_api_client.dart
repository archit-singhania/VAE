import 'dart:convert';

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
  const RegistrationResult({this.accessToken, this.onboardingToken, required this.accountStatus});
  final String? accessToken;
  final String? onboardingToken;
  final String accountStatus;
}

class PaymentInstructions {
  const PaymentInstructions({required this.amount, required this.currency, required this.upiId, required this.qrUrl, required this.supportEmail});
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
/// Defaults to the Android emulator's host-loopback address; override with
/// `--dart-define=API_BASE_URL=http://localhost:8000/api/v1` for iOS
/// simulator / desktop, or a real host for a device on the network.
class AevraApiClient {
  AevraApiClient({String? baseUrl})
      : baseUrl = baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://10.0.2.2:8000/api/v1',
            );

  final String baseUrl;

  Uri _uri(String path) => Uri.parse('$baseUrl${path.startsWith('/') ? path : '/$path'}');

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
      case 'POST':
        response = await http.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
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
          message = detail.map((e) => (e as Map)['msg']).where((e) => e != null).join('. ');
        } else if (payload['error'] is Map && payload['error']['message'] != null) {
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
          accessToken: (json['token'] as Map<String, dynamic>?)?['access_token'] as String?,
          onboardingToken: json['onboarding_token'] as String?,
          accountStatus: json['account_status'] as String? ?? 'pending_payment',
        ),
      );

  Future<AevraUser> me(String token) => _request<AevraUser>(
        '/auth/me',
        token: token,
        parse: (json) => AevraUser.fromJson(json as Map<String, dynamic>),
      );

  Future<PaymentInstructions> paymentInstructions() => _request<PaymentInstructions>(
        '/auth/onboarding/payment-instructions',
        parse: (json) => PaymentInstructions(
          amount: json['amount'] as String? ?? '0',
          currency: json['currency'] as String? ?? 'INR',
          upiId: json['upi_id'] as String? ?? '',
          qrUrl: json['qr_url'] as String? ?? '',
          supportEmail: json['support_email'] as String? ?? '',
        ),
      );

  Future<void> submitPayment(String onboardingToken, String utr, {String? note}) => _request<void>(
        '/auth/onboarding/payment-submissions/public',
        method: 'POST',
        body: {'onboarding_token': onboardingToken, 'utr_reference': utr, if (note != null) 'note': note},
        parse: (_) => null,
      );

  Future<List<Workspace>> workspaces(String token) => _request<List<Workspace>>(
        '/workspaces',
        token: token,
        parse: (json) => (json as List).map((e) => Workspace.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Future<List<Brand>> brands(String token, String workspaceId) => _request<List<Brand>>(
        '/workspaces/$workspaceId/brands',
        token: token,
        parse: (json) => (json as List).map((e) => Brand.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Future<List<Campaign>> campaigns(String token, String workspaceId) => _request<List<Campaign>>(
        '/workspaces/$workspaceId/campaigns',
        token: token,
        parse: (json) => (json as List).map((e) => Campaign.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Future<List<ContentVariant>> variants(String token, String workspaceId, String campaignId) =>
      _request<List<ContentVariant>>(
        '/workspaces/$workspaceId/campaigns/$campaignId/variants',
        token: token,
        parse: (json) =>
            (json as List).map((e) => ContentVariant.fromJson(e as Map<String, dynamic>)).toList(),
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
        parse: (json) => Campaign.fromJson((json as Map<String, dynamic>)['campaign'] as Map<String, dynamic>),
      );

  Future<List<KnowledgeDocument>> documents(String token, String workspaceId) =>
      _request<List<KnowledgeDocument>>(
        '/workspaces/$workspaceId/knowledge/documents',
        token: token,
        parse: (json) =>
            (json as List).map((e) => KnowledgeDocument.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Future<List<MediaAsset>> media(String token, String workspaceId) => _request<List<MediaAsset>>(
        '/workspaces/$workspaceId/media/assets',
        token: token,
        parse: (json) => (json as List).map((e) => MediaAsset.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Future<List<MediaAsset>> generateImage(
    String token,
    String workspaceId,
    String prompt,
  ) =>
      _request<List<MediaAsset>>(
        '/workspaces/$workspaceId/media/images/generate',
        token: token,
        method: 'POST',
        body: {
          'campaign_id': null,
          'prompt': prompt,
          'platforms': ['instagram'],
          'aspect_ratio': '1:1',
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
        parse: (json) =>
            (json as List).map((e) => SocialAccount.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Future<List<ScheduledPost>> scheduled(String token, String workspaceId) =>
      _request<List<ScheduledPost>>(
        '/workspaces/$workspaceId/operations/schedule',
        token: token,
        parse: (json) =>
            (json as List).map((e) => ScheduledPost.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

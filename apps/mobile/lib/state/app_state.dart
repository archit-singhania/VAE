import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/aevra_api_client.dart';
import '../api/models.dart';

/// Holds auth + workspace data for the whole app, mirroring the state
/// LiveWorkspace (apps/web/components/live-workspace.tsx) keeps in React.
/// Screens read from this via [MobileShell] instead of calling the API
/// client directly.
class AppState extends ChangeNotifier {
  AppState({AevraApiClient? client}) : client = client ?? AevraApiClient();

  final AevraApiClient client;
  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'aevra.mobile.access-token';
  static String? _debugMacAccessToken;

  /// Keychain Sharing needs a local Apple development signing identity on
  /// macOS. Keep Debug desktop sessions in memory so this local preview can
  /// be used without signing credentials; iOS and all non-Debug builds keep
  /// using platform secure storage.
  bool get _usesDebugMacSession =>
      kDebugMode && defaultTargetPlatform == TargetPlatform.macOS;

  Future<void> _saveAccessToken(String value) async {
    if (_usesDebugMacSession) {
      _debugMacAccessToken = value;
    } else {
      await _storage.write(key: _tokenKey, value: value);
    }
  }

  String? token;
  bool hydrated = false;
  bool loading = false;
  String? error;
  String? onboardingToken;
  PaymentInstructions? paymentInfo;
  bool get paymentPending => onboardingToken != null;

  AevraUser? user;
  Workspace? workspace;
  List<Brand> brands = [];
  List<Campaign> campaigns = [];
  List<KnowledgeDocument> documents = [];
  List<MediaAsset> assets = [];
  List<SocialAccount> accounts = [];
  List<ScheduledPost> scheduled = [];
  List<PostMetric> metrics = [];
  String draftPrompt = '';
  String draftCaption = '';
  String? publishAssetId;
  void selectForPublishing(String? assetId, {String? caption}) {
    publishAssetId = assetId;
    if (caption != null) draftCaption = caption;
    notifyListeners();
  }

  void updateUser(AevraUser updated) {
    user = updated;
    notifyListeners();
  }

  bool get authenticated => token != null;

  Future<void> hydrate() async {
    token = _usesDebugMacSession
        ? _debugMacAccessToken
        : await _storage.read(key: _tokenKey);
    hydrated = true;
    notifyListeners();
    if (token != null) await load();
  }

  Future<void> login(String email, String password) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final accessToken = await client.login(email, password);
      await _saveAccessToken(accessToken);
      token = accessToken;
      await load();
    } catch (caught) {
      error = caught.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    required String organizationName,
    required String workspaceName,
    required String accountType,
    required String timezone,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final registration = await client.register(
        email: email,
        password: password,
        displayName: displayName,
        organizationName: organizationName,
        workspaceName: workspaceName,
        accountType: accountType,
        timezone: timezone,
      );
      if (registration.accessToken == null) {
        onboardingToken = registration.onboardingToken;
        paymentInfo = await client.paymentInstructions();
        error = null;
      } else {
        await _saveAccessToken(registration.accessToken!);
        token = registration.accessToken;
        await load();
      }
    } catch (caught) {
      error = caught.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> submitPayment(String utr, {String? note}) async {
    final current = onboardingToken;
    if (current == null) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      await client.submitPayment(current, utr, note: note);
      onboardingToken = null;
      paymentInfo = null;
      error =
          'Payment submitted for manual verification. Sign in after approval.';
    } catch (caught) {
      error = caught.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> load() async {
    final currentToken = token;
    if (currentToken == null) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final me = await client.me(currentToken);
      final workspaces = await client.workspaces(currentToken);
      final nextWorkspace = workspaces.isNotEmpty ? workspaces.first : null;
      if (nextWorkspace == null) throw Exception('No active workspace found.');

      final results = await Future.wait([
        client.brands(currentToken, nextWorkspace.id),
        client.campaigns(currentToken, nextWorkspace.id),
        client.documents(currentToken, nextWorkspace.id),
        client.media(currentToken, nextWorkspace.id),
        client.accounts(currentToken, nextWorkspace.id),
        client.scheduled(currentToken, nextWorkspace.id),
        client.metrics(currentToken, nextWorkspace.id),
      ]);

      user = me;
      workspace = nextWorkspace;
      brands = results[0] as List<Brand>;
      campaigns = results[1] as List<Campaign>;
      documents = results[2] as List<KnowledgeDocument>;
      assets = results[3] as List<MediaAsset>;
      accounts = results[4] as List<SocialAccount>;
      scheduled = results[5] as List<ScheduledPost>;
      metrics = results[6] as List<PostMetric>;
    } catch (caught) {
      if (caught is ApiException && caught.status == 401) {
        await signOut();
      }
      error = caught.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> decide(String campaignId, String decision) async {
    final currentToken = token;
    final currentWorkspace = workspace;
    if (currentToken == null || currentWorkspace == null) return;
    try {
      final updated = await client.decideCampaign(
          currentToken, currentWorkspace.id, campaignId, decision);
      campaigns =
          campaigns.map((c) => c.id == campaignId ? updated : c).toList();
      notifyListeners();
    } catch (caught) {
      error = caught.toString();
      notifyListeners();
    }
  }

  void prependAssets(List<MediaAsset> created) {
    assets = [...created, ...assets];
    error = null;
    notifyListeners();
  }

  void addBrand(Brand brand) {
    brands = [brand, ...brands.where((item) => item.id != brand.id)];
    notifyListeners();
  }

  void addDocument(KnowledgeDocument document) {
    documents = [
      document,
      ...documents.where((item) => item.id != document.id)
    ];
    notifyListeners();
  }

  void reportError(Object caught) {
    error = caught.toString();
    notifyListeners();
  }

  Future<void> signOut() async {
    if (_usesDebugMacSession) {
      _debugMacAccessToken = null;
    } else {
      await _storage.delete(key: _tokenKey);
    }
    token = null;
    user = null;
    workspace = null;
    brands = [];
    campaigns = [];
    documents = [];
    assets = [];
    accounts = [];
    scheduled = [];
    metrics = [];
    draftPrompt = '';
    draftCaption = '';
    publishAssetId = null;
    notifyListeners();
  }
}

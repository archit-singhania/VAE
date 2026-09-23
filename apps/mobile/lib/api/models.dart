/// Response models mirroring apps/web/lib/api.ts, kept intentionally simple
/// (plain fields + fromJson) so both platforms speak the same shapes.
library;

class AevraUser {
  final String id;
  final String email;
  final String displayName;
  final String? brandName;
  final String? avatarUrl;
  final String accountType;
  final bool isAdmin;

  AevraUser(
      {required this.id,
      required this.email,
      required this.displayName,
      this.brandName,
      this.avatarUrl,
      this.accountType = 'creator',
      this.isAdmin = false});

  factory AevraUser.fromJson(Map<String, dynamic> json) => AevraUser(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['display_name'] as String? ?? '',
        brandName: json['brand_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        accountType: json['account_type'] as String? ?? 'creator',
        isAdmin: json['is_admin'] as bool? ?? false,
      );
}

class Workspace {
  final String id;
  final String name;
  final String timezone;

  Workspace({required this.id, required this.name, required this.timezone});

  factory Workspace.fromJson(Map<String, dynamic> json) => Workspace(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        timezone: json['timezone'] as String? ?? '',
      );
}

class Brand {
  final String id;
  final String name;
  final String description;

  Brand({required this.id, required this.name, required this.description});

  factory Brand.fromJson(Map<String, dynamic> json) => Brand(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
      );
}

class Campaign {
  final String id;
  final String name;
  final String status;
  final List<String> platforms;
  final String updatedAt;

  Campaign({
    required this.id,
    required this.name,
    required this.status,
    required this.platforms,
    required this.updatedAt,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) => Campaign(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        status: json['status'] as String? ?? 'draft',
        platforms:
            (json['platforms'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        updatedAt: json['updated_at'] as String? ?? '',
      );
}

class ContentVariant {
  final String id;
  final String platform;
  final String caption;
  final double qualityScore;
  final String status;

  ContentVariant({
    required this.id,
    required this.platform,
    required this.caption,
    required this.qualityScore,
    required this.status,
  });

  factory ContentVariant.fromJson(Map<String, dynamic> json) => ContentVariant(
        id: json['id'] as String,
        platform: json['platform'] as String? ?? '',
        caption: json['caption'] as String? ?? '',
        qualityScore: (json['quality_score'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String? ?? 'draft',
      );
}

class KnowledgeDocument {
  final String id;
  final String title;
  final String sourceType;
  final int contentLength;
  final String status;

  KnowledgeDocument({
    required this.id,
    required this.title,
    required this.sourceType,
    required this.contentLength,
    required this.status,
  });

  factory KnowledgeDocument.fromJson(Map<String, dynamic> json) =>
      KnowledgeDocument(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        sourceType: json['source_type'] as String? ?? '',
        contentLength: (json['content_length'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? '',
      );
}

class MediaAsset {
  final String id;
  final String filename;
  final String mediaType;
  final String status;
  final String? downloadUrl;
  final String createdAt;

  MediaAsset({
    required this.id,
    required this.filename,
    required this.mediaType,
    required this.status,
    required this.downloadUrl,
    required this.createdAt,
  });

  factory MediaAsset.fromJson(Map<String, dynamic> json) => MediaAsset(
        id: json['id'] as String,
        filename: json['filename'] as String? ?? '',
        mediaType: json['media_type'] as String? ?? 'image',
        status: json['status'] as String? ?? '',
        downloadUrl: json['download_url'] as String?,
        createdAt: json['created_at'] as String? ?? '',
      );
}

class SocialAccount {
  final String id;
  final String platform;
  final String displayName;
  final String status;

  SocialAccount({
    required this.id,
    required this.platform,
    required this.displayName,
    required this.status,
  });

  factory SocialAccount.fromJson(Map<String, dynamic> json) => SocialAccount(
        id: json['id'] as String,
        platform: json['platform'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        status: json['status'] as String? ?? '',
      );
}

class ScheduledPost {
  final String id;
  final String scheduledFor;
  final String status;
  final String? text;

  ScheduledPost({
    required this.id,
    required this.scheduledFor,
    required this.status,
    required this.text,
  });

  factory ScheduledPost.fromJson(Map<String, dynamic> json) => ScheduledPost(
        id: json['id'] as String,
        scheduledFor: json['scheduled_for'] as String? ?? '',
        status: json['status'] as String? ?? '',
        text: (json['payload'] as Map<String, dynamic>?)?['text'] as String?,
      );
}

class PostMetric {
  PostMetric(Map<String, dynamic> json)
      : id = json['id'] as String,
        accountId = json['social_account_id'] as String,
        postId = json['external_post_id'] as String? ?? '',
        collectedAt = DateTime.parse(json['collected_at'] as String),
        impressions = (json['impressions'] as num? ?? 0).toInt(),
        engagements = (json['engagements'] as num? ?? 0).toInt();
  final String id, accountId, postId;
  final DateTime collectedAt;
  final int impressions, engagements;
}

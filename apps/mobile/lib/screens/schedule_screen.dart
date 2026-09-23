import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/models.dart';
import '../state/app_state.dart';
import '../widgets/vae_ui.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.state});
  final AppState state;
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late final TextEditingController caption =
      TextEditingController(text: widget.state.draftCaption);
  final selected = <String>{};
  final delivery = <String, String>{};
  DateTime? when;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    caption.dispose();
    super.dispose();
  }

  Future<void> chooseTime() async {
    final day = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (day == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (time != null && mounted) {
      setState(() => when =
          DateTime(day.year, day.month, day.day, time.hour, time.minute));
    }
  }

  Future<void> upload() async {
    final s = widget.state;
    if (s.token == null || s.workspace == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final asset = await s.client.pickAndUpload(s.token!, s.workspace!.id);
      if (asset != null) {
        s.prependAssets([asset]);
        s.selectForPublishing(asset.id);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> publish() async {
    final s = widget.state;
    if (s.token == null || s.workspace == null) return;
    if (selected.isEmpty ||
        (caption.text.trim().isEmpty && s.publishAssetId == null)) {
      setState(() => error = 'Choose a channel and add media or a caption.');
      return;
    }
    if (when != null && !when!.isAfter(DateTime.now())) {
      setState(() => error = 'Choose a future time.');
      return;
    }
    final names = s.accounts
        .where((a) => selected.contains(a.id))
        .map((a) => a.displayName)
        .join(', ');
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(
                  when == null ? 'Publish this post?' : 'Schedule this post?'),
              content: SingleChildScrollView(
                  child: Text(
                      '$names\n\n${caption.text}\n\n${when?.toLocal().toString() ?? 'Publish now'}')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep editing')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Confirm'))
              ],
            ));
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
      delivery.clear();
    });
    final asset = s.assets.where((a) => a.id == s.publishAssetId).firstOrNull;
    for (final id in selected.toList()) {
      try {
        final result = await s.client.publish(
            s.token!,
            s.workspace!.id,
            {
              'campaign_id': null,
              'social_account_id': id,
              'idempotency_key':
                  'vae-mobile-${DateTime.now().microsecondsSinceEpoch}-$id',
              'text': caption.text.trim(),
              'media_urls':
                  asset?.downloadUrl == null ? [] : [asset!.downloadUrl],
              if (when != null)
                'scheduled_for': when!.toUtc().toIso8601String(),
            },
            schedule: when != null);
        if (mounted) {
          setState(
              () => delivery[id] = result['status'] as String? ?? 'queued');
        }
      } catch (e) {
        if (mounted) setState(() => delivery[id] = 'Failed: $e');
      }
    }
    await s.load();
    if (mounted) setState(() => busy = false);
  }

  Future<void> update(String id, String action) async {
    final s = widget.state;
    if (s.token == null || s.workspace == null) return;
    setState(() => busy = true);
    try {
      await s.client.updateScheduled(s.token!, s.workspace!.id, id, action);
      await s.load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> connect(String provider) async {
    final s = widget.state;
    if (s.token == null || s.workspace == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final url =
          await s.client.authorizeChannel(s.token!, s.workspace!.id, provider);
      if (!await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication)) {
        throw Exception('Unable to open the provider sign-in page.');
      }
    } catch (e) {
      if (mounted) setState(() => error = '$provider: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> disconnect(SocialAccount account) async {
    final s = widget.state;
    if (s.token == null || s.workspace == null) return;
    setState(() => busy = true);
    try {
      await s.client.disconnectChannel(s.token!, s.workspace!.id, account);
      selected.remove(account.id);
      await s.load();
    } catch (e) {
      if (mounted) setState(() => error = '${account.platform}: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final s = widget.state;
        return VaeScaffold(children: [
          const VaePageHeader(
              'Publish', 'Your media. Your channels. The right moment.'),
          VaeGlassCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                DropdownButtonFormField<String>(
                    key: ValueKey(s.publishAssetId),
                    initialValue: s.assets.any((a) => a.id == s.publishAssetId)
                        ? s.publishAssetId
                        : null,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: '1. Select media'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Text-only post')),
                      ...s.assets.where((a) => a.status == 'ready').map((a) =>
                          DropdownMenuItem(
                              value: a.id,
                              child: Text(a.filename,
                                  overflow: TextOverflow.ellipsis)))
                    ],
                    onChanged: busy ? null : (id) => s.selectForPublishing(id)),
                OutlinedButton.icon(
                    onPressed: busy ? null : upload,
                    icon: const Icon(Icons.upload),
                    label: const Text('Upload an asset')),
                const SizedBox(height: 24),
                const Text('2. Choose channels'),
                if (!s.accounts.any((a) => a.status == 'connected'))
                  const Text(
                      'Connect a social channel below to begin publishing.'),
                ...s.accounts.map((a) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selected.contains(a.id),
                    onChanged: busy || a.status != 'connected'
                        ? null
                        : (value) => setState(() {
                              value == true
                                  ? selected.add(a.id)
                                  : selected.remove(a.id);
                            }),
                    title: Text(a.displayName),
                    subtitle: Text('${a.platform} · ${a.status}'))),
                const SizedBox(height: 16),
                TextField(
                    controller: caption,
                    minLines: 3,
                    maxLines: 8,
                    onChanged: (v) => s.draftCaption = v,
                    decoration: const InputDecoration(labelText: '3. Caption')),
                const SizedBox(height: 16),
                Wrap(spacing: 12, children: [
                  OutlinedButton(
                      onPressed: busy ? null : chooseTime,
                      child: Text(when == null
                          ? 'Schedule for later'
                          : when!.toLocal().toString())),
                  if (when != null)
                    TextButton(
                        onPressed:
                            busy ? null : () => setState(() => when = null),
                        child: const Text('Publish now instead'))
                ]),
                if (error != null)
                  Semantics(
                      liveRegion: true,
                      child: Text(error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
                const SizedBox(height: 16),
                VaePrimaryButton('Review ${when == null ? 'post' : 'schedule'}',
                    busy: busy, onPressed: publish),
                ...delivery.entries.map((e) => ListTile(
                    title: Text(s.accounts
                            .where((a) => a.id == e.key)
                            .firstOrNull
                            ?.displayName ??
                        'Channel'),
                    subtitle: Text(e.value))),
              ])),
          const SizedBox(height: 32),
          ExpansionTile(title: const Text('Connected channels'), children: [
            const Text(
                'After approving access in your browser, return here and refresh channels.'),
            Wrap(
                spacing: 8,
                children: [
                  'instagram',
                  'facebook',
                  'threads',
                  'linkedin',
                  'youtube'
                ]
                    .map((p) => OutlinedButton(
                        onPressed: busy ? null : () => connect(p),
                        child: Text(p)))
                    .toList()),
            TextButton(
                onPressed: busy ? null : s.load,
                child: const Text('Refresh channels')),
            ...s.accounts.map((a) => ListTile(
                title: Text(a.displayName),
                subtitle: Text('${a.platform} · ${a.status}'),
                trailing: TextButton(
                    onPressed: busy
                        ? null
                        : () => a.status == 'revoked'
                            ? connect(a.platform)
                            : disconnect(a),
                    child: Text(
                        a.status == 'revoked' ? 'Reconnect' : 'Disconnect')))),
          ]),
          Text('Publishing timeline',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          if (s.scheduled.isEmpty)
            const VaeEmptyState('No scheduled posts',
                'Choose media above and make a plan for your next post.'),
          ...s.scheduled.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: VaeGlassCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(p.text ?? 'Media post'),
                    const SizedBox(height: 8),
                    Text(p.scheduledFor),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, children: [
                      VaeStatusPill(p.status),
                      if (p.status == 'failed')
                        TextButton(
                            onPressed:
                                busy ? null : () => update(p.id, 'retry'),
                            child: const Text('Retry')),
                      if (p.status == 'scheduled')
                        TextButton(
                            onPressed:
                                busy ? null : () => update(p.id, 'cancel'),
                            child: const Text('Cancel'))
                    ])
                  ])))),
        ]);
      });
}

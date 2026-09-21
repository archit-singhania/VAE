import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/aevra_theme.dart';
import '../widgets/depth.dart';

class MediaScreen extends StatefulWidget {
  const MediaScreen({super.key, required this.state});
  final AppState state;

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  final prompt = TextEditingController();
  bool generating = false;

  @override
  void dispose() {
    prompt.dispose();
    super.dispose();
  }

  Future<void> generate() async {
    final token = widget.state.token;
    final workspace = widget.state.workspace;
    if (token == null || workspace == null || prompt.text.trim().length < 3) return;
    setState(() => generating = true);
    try {
      final created = await widget.state.client.generateImage(token, workspace.id, prompt.text.trim());
      widget.state.assets.insertAll(0, created);
      widget.state.notifyListeners();
      prompt.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Media added to your library.')));
    } catch (error) {
      widget.state.error = error.toString();
      widget.state.notifyListeners();
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.state,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(AevraSpace.lg),
          children: [
            Text('Create media', style: AevraType.display(30)),
            const SizedBox(height: AevraSpace.xs),
            const Text('Create an image now, then publish it to connected channels.', style: TextStyle(color: AevraColors.textSoft)),
            const SizedBox(height: AevraSpace.lg),
            GlassSurface(
              padding: const EdgeInsets.all(AevraSpace.lg),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Describe your content', style: AevraType.eyebrow()),
                const SizedBox(height: AevraSpace.sm),
                TextField(controller: prompt, minLines: 4, maxLines: 7, decoration: const InputDecoration(hintText: 'A premium product launch image for…')),
                const SizedBox(height: AevraSpace.md),
                SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: generating ? null : generate, icon: const Icon(Icons.auto_awesome), label: Text(generating ? 'Creating…' : 'Generate image'))),
              ]),
            ),
            const SizedBox(height: AevraSpace.lg),
            Text('Asset library', style: AevraType.display(22)),
            const SizedBox(height: AevraSpace.sm),
            if (widget.state.assets.isEmpty)
              const Text('Your generated and uploaded media will appear here.', style: TextStyle(color: AevraColors.muted))
            else
              ...widget.state.assets.map((asset) => ListTile(leading: const Icon(Icons.image_outlined), title: Text(asset.filename), subtitle: Text('${asset.mediaType} · ${asset.status}'))),
          ],
        ),
      );
}

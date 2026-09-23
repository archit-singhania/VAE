import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../widgets/vae_ui.dart';

class MediaScreen extends StatefulWidget {
  const MediaScreen({super.key, required this.state, this.onPublish});
  final AppState state;
  final VoidCallback? onPublish;
  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  late final TextEditingController prompt =
      TextEditingController(text: widget.state.draftPrompt);
  bool generating = false, uploading = false;
  String mode = 'image', ratio = '1:1', generatedText = '', progress = '';
  int count = 1, limit = 12;
  String? error;
  @override
  void dispose() {
    prompt.dispose();
    super.dispose();
  }

  Future<void> generate() async {
    final state = widget.state;
    if (state.token == null ||
        state.workspace == null ||
        prompt.text.trim().length < 3) {
      setState(() => error = 'Enter a prompt of at least 3 characters.');
      return;
    }
    final brief = prompt.text;
    final outputs = count;
    final aspect = ratio;
    setState(() {
      generating = true;
      error = null;
    });
    try {
      if (mode == 'text') {
        final text = await state.client.generateText(
            state.token!, state.workspace!.id, prompt.text, (value) {
          if (mounted) setState(() => generatedText = value);
        });
        state.draftCaption = text;
      } else {
        for (var i = 0; i < outputs; i++) {
          if (mounted) {
            setState(() => progress = 'Generating image ${i + 1} of $outputs…');
          }
          final created = await state.client.generateImage(
              state.token!, state.workspace!.id, brief,
              aspectRatio: aspect);
          state.prependAssets(created);
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          generating = false;
          progress = '';
        });
      }
    }
  }

  Future<void> upload() async {
    final s = widget.state;
    if (s.token == null || s.workspace == null) return;
    setState(() {
      uploading = true;
      error = null;
    });
    try {
      final asset = await s.client.pickAndUpload(s.token!, s.workspace!.id);
      if (asset != null) s.prependAssets([asset]);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) => VaeScaffold(children: [
            const VaePageHeader(
                'Create', 'Turn a thought into something worth sharing.'),
            VaeGlassCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'image',
                            label: Text('Image'),
                            icon: Icon(Icons.image_outlined)),
                        ButtonSegment(
                            value: 'text',
                            label: Text('Text'),
                            icon: Icon(Icons.notes))
                      ],
                      selected: {
                        mode
                      },
                      onSelectionChanged: generating
                          ? null
                          : (s) => setState(() => mode = s.first)),
                  const SizedBox(height: 24),
                  TextField(
                      controller: prompt,
                      minLines: 4,
                      maxLines: 8,
                      onChanged: (v) => widget.state.draftPrompt = v,
                      decoration: const InputDecoration(
                          labelText: 'Describe your idea',
                          hintText:
                              'A product portrait in warm morning light…')),
                  const SizedBox(height: 16),
                  if (mode == 'image')
                    Wrap(spacing: 16, runSpacing: 16, children: [
                      DropdownButton<String>(
                          value: ratio,
                          items: ['1:1', '4:5', '9:16', '16:9']
                              .map((r) =>
                                  DropdownMenuItem(value: r, child: Text(r)))
                              .toList(),
                          onChanged: generating
                              ? null
                              : (v) => setState(() => ratio = v!)),
                      DropdownButton<int>(
                          value: count,
                          items: [1, 2, 3, 4]
                              .map((n) => DropdownMenuItem(
                                  value: n,
                                  child: Text(
                                      '$n ${n == 1 ? 'image' : 'images'}')))
                              .toList(),
                          onChanged: generating
                              ? null
                              : (v) => setState(() => count = v!)),
                    ]),
                  if (error != null)
                    Text(error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  if (generating) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    Semantics(
                        liveRegion: true,
                        child: Text(mode == 'text'
                            ? 'Writing your caption…'
                            : progress))
                  ],
                  const SizedBox(height: 16),
                  VaePrimaryButton(
                      mode == 'image' ? 'Generate image' : 'Generate caption',
                      busy: generating,
                      onPressed: generate),
                  OutlinedButton.icon(
                      onPressed: uploading ? null : upload,
                      icon: const Icon(Icons.upload),
                      label:
                          Text(uploading ? 'Uploading…' : 'Upload an asset')),
                  if (generatedText.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SelectableText(generatedText),
                    TextButton(
                        onPressed: () {
                          widget.state.selectForPublishing(null,
                              caption: generatedText);
                          widget.onPublish?.call();
                        },
                        child: const Text('Use for publishing'))
                  ],
                ])),
            const SizedBox(height: 32),
            Text('Asset library',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            if (widget.state.assets.isEmpty)
              const VaeEmptyState('Your library is empty',
                  'Describe a visual above or upload your own media.'),
            ...widget.state.assets
                .take(limit)
                .map((a) => VaeAssetTile(a, onPublish: () {
                      widget.state.selectForPublishing(a.id);
                      widget.onPublish?.call();
                    })),
            if (widget.state.assets.length > limit)
              TextButton(
                  onPressed: () => setState(() => limit += 12),
                  child: const Text('Show more assets')),
          ]));
}

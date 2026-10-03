import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import '../state/app_state.dart';
import 'vae_ui.dart';
import 'depth.dart';

class VaeProfileSheet extends StatefulWidget {
  const VaeProfileSheet(
      {super.key, required this.state, required this.onSignOut});
  final AppState state;
  final VoidCallback onSignOut;
  @override
  State<VaeProfileSheet> createState() => _VaeProfileSheetState();
}

class _VaeProfileSheetState extends State<VaeProfileSheet> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.state.user?.displayName);
  late final email = TextEditingController(text: widget.state.user?.email);
  late final brand = TextEditingController(text: widget.state.user?.brandName);
  final current = TextEditingController(), password = TextEditingController();
  late String? avatar = widget.state.user?.avatarUrl;
  bool busy = false;
  String? error, notice;
  @override
  void dispose() {
    for (final c in [name, email, brand, current, password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> upload() async {
    final s = widget.state;
    if (s.token == null || s.workspace == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await s.client
          .pickAndUpload(s.token!, s.workspace!.id, imagesOnly: true);
      if (result != null && mounted) {
        final updated = await s.client.updateProfile(s.token!, {
          'display_name': name.text.trim(),
          'email': email.text.trim(),
          'brand_name': brand.text.trim(),
          'avatar_url': result.downloadUrl,
          'account_type': s.user!.accountType
        });
        s.updateUser(updated);
        setState(() {
          avatar = result.downloadUrl;
          notice = 'Profile picture updated.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final s = widget.state;
    if (s.token == null || s.user == null) return;
    setState(() {
      busy = true;
      error = null;
      notice = null;
    });
    try {
      final updated = await s.client.updateProfile(s.token!, {
        'display_name': name.text.trim(),
        'email': email.text.trim(),
        'brand_name': brand.text.trim(),
        'avatar_url': avatar,
        'account_type': s.user!.accountType
      });
      s.updateUser(updated);
      if (password.text.isNotEmpty) {
        await s.client.changePassword(s.token!, current.text, password.text);
        current.clear();
        password.clear();
      }
      if (mounted) setState(() => notice = 'Profile saved.');
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            12, 16, 12, MediaQuery.viewInsetsOf(context).bottom + 8),
        child: GlassChrome(
          radius: 32,
          dense: true,
          padding: EdgeInsets.zero,
          child: Material(
            color: Colors.transparent,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 34,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: colors.onSurface.withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your profile',
                                style: theme.textTheme.headlineMedium),
                            const SizedBox(height: 5),
                            Text('A little more you.',
                                style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close profile',
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              colors.onSurface.withValues(alpha: .06),
                        ),
                        icon: const Icon(LucideIcons.x, size: 18),
                      ),
                    ]),
                    const SizedBox(height: 28),
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: colors.primary.withValues(alpha: .22)),
                          color: colors.primary.withValues(alpha: .08),
                        ),
                        child: ClipOval(
                          child: avatar == null
                              ? Icon(LucideIcons.userRound,
                                  color: colors.primary, size: 28)
                              : Image.network(avatar!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, error, stack) => Icon(
                                      LucideIcons.userRound,
                                      color: colors.primary,
                                      size: 28)),
                        ),
                      ),
                    ),
                    TextButton.icon(
                        onPressed: busy ? null : upload,
                        icon: const Icon(LucideIcons.camera, size: 16),
                        label: const Text('Upload profile image')),
                    const SizedBox(height: 20),
                    Text('Personal details',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 14),
                    TextFormField(
                        controller: name,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        decoration: const InputDecoration(
                            prefixIcon: Icon(LucideIcons.userRound, size: 18),
                            labelText: 'Display name'),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter a name.'
                            : null),
                    const SizedBox(height: 14),
                    TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                            prefixIcon: Icon(LucideIcons.mail, size: 18),
                            labelText: 'Email'),
                        validator: (v) => v == null || !v.contains('@')
                            ? 'Enter a valid email.'
                            : null),
                    const SizedBox(height: 14),
                    TextFormField(
                        controller: brand,
                        decoration: const InputDecoration(
                            prefixIcon:
                                Icon(LucideIcons.briefcaseBusiness, size: 18),
                            labelText: 'Product or brand')),
                    const SizedBox(height: 28),
                    Text('Security', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text('Update your password when you need to.',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 14),
                    TextFormField(
                        controller: current,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration: const InputDecoration(
                            prefixIcon: Icon(LucideIcons.lockKeyhole, size: 18),
                            labelText: 'Current password'),
                        validator: (v) =>
                            password.text.isNotEmpty && (v == null || v.isEmpty)
                                ? 'Enter your current password.'
                                : null),
                    const SizedBox(height: 14),
                    TextFormField(
                        controller: password,
                        obscureText: true,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: const InputDecoration(
                            prefixIcon: Icon(LucideIcons.keyRound, size: 18),
                            labelText: 'New password (optional)'),
                        validator: (v) =>
                            v != null && v.isNotEmpty && v.length < 8
                                ? 'Use at least 8 characters.'
                                : null),
                    const SizedBox(height: 22),
                    if (error != null) ...[
                      Semantics(
                          liveRegion: true,
                          child: Text(error!,
                              style: TextStyle(color: colors.error))),
                      const SizedBox(height: 12),
                    ],
                    if (notice != null) ...[
                      Semantics(
                          liveRegion: true,
                          child: Text(notice!,
                              style: TextStyle(color: colors.secondary))),
                      const SizedBox(height: 12),
                    ],
                    VaePrimaryButton('Save profile',
                        busy: busy, onPressed: save),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onSignOut();
                      },
                      icon: const Icon(LucideIcons.logOut, size: 16),
                      label: const Text('Sign out'),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      style:
                          TextButton.styleFrom(foregroundColor: colors.error),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Account deletion'),
                          content: const SelectableText(
                              'To request deletion, open the Account deletion page from the VAE web sign-in screen. You will find the account verification and deletion instructions there.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close')),
                          ],
                        ),
                      ),
                      child: const Text('Delete account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

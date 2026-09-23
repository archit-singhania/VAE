import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/aevra_theme.dart';
import '../widgets/aevra_logo.dart';
import '../widgets/depth.dart';
import '../widgets/landing_video.dart';
import '../widgets/shader_background.dart';

/// The mobile counterpart of the web app's `.live-auth` screen — same
/// shader background + glass auth card, same login/register fields.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.state});

  final AppState state;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _org = TextEditingController();
  String _accountType = 'creator';
  final _utr = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _org.dispose();
    _utr.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_email.text.contains('@') ||
        _password.text.length < 8 ||
        (!isLogin && _name.text.trim().isEmpty)) {
      widget.state.reportError(
          'Enter a valid email, a password of at least 8 characters, and your name when registering.');
      return;
    }
    if (isLogin) {
      await widget.state.login(_email.text.trim(), _password.text);
    } else {
      await widget.state.register(
        email: _email.text.trim(),
        password: _password.text,
        displayName: _name.text.trim(),
        organizationName: _org.text.trim(),
        workspaceName: 'Content Studio',
        accountType: _accountType,
        timezone: DateTime.now().timeZoneName,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          if (Theme.of(context).brightness == Brightness.dark)
            const Positioned.fill(
                child: RepaintBoundary(child: ShaderBackground())),
          // The original MOV artwork is optional and never blocks the first
          // frame. LandingVideo fades in only after local codec support is
          // confirmed; ShaderBackground remains the free fallback.
          const Positioned.fill(child: LandingVideo()),
          SafeArea(
            child: AnimatedBuilder(
              animation: widget.state,
              builder: (context, _) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(AevraSpace.lg,
                      AevraSpace.xxl, AevraSpace.lg, AevraSpace.xl),
                  child: _AuthLayout(
                    children: [
                      const AevraWordmark(markSize: 30, fontSize: 17),
                      const SizedBox(height: AevraSpace.xxl),
                      Text('YOUR CREATIVE WORKSPACE',
                          style: AevraType.eyebrow()),
                      const SizedBox(height: AevraSpace.sm),
                      Text(
                        'Your ideas.\nBeautifully made.',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: AevraSpace.md),
                      Text(
                        'A quiet space to create media, connect your channels, and share what matters.',
                        style: TextStyle(
                            fontSize: 13.5,
                            height: 1.6,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: AevraSpace.lg),
                      // Three proof points, set as a mono rail. On a phone
                      // these do the job the web hero's feature column does.
                      ...[
                        'Create media.',
                        'Connect channels.',
                        'Publish on schedule.',
                      ].map(
                        (point) => Padding(
                          padding: const EdgeInsets.only(bottom: AevraSpace.xs),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.only(
                                    top: 6, right: AevraSpace.sm),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AevraColors.accent,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  point,
                                  style: const TextStyle(
                                      fontSize: 12, color: AevraColors.muted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AevraSpace.xl),
                      // The one surface on this screen, so it gets the top
                      // tier — but no tilt. A tap-down tilt recogniser here
                      // would enter the gesture arena against every TextField
                      // inside it, which risks taps not reliably focusing a
                      // field. Depth on a form isn't worth that.
                      GlassSurface(
                        elevation: GlassElevation.lifted,
                        radius: AevraRadius.lg,
                        padding: const EdgeInsets.all(AevraSpace.lg),
                        adaptive: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _Tab(
                                    label: 'Sign in',
                                    active: isLogin,
                                    onTap: () =>
                                        setState(() => isLogin = true)),
                                const SizedBox(width: AevraSpace.lg),
                                _Tab(
                                    label: 'Get started',
                                    active: !isLogin,
                                    onTap: () =>
                                        setState(() => isLogin = false)),
                              ],
                            ),
                            const SizedBox(height: AevraSpace.lg),
                            Text(
                              isLogin
                                  ? 'Welcome back'
                                  : 'Create your VAE account',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: AevraSpace.md),
                            if (widget.state.error != null) ...[
                              _ErrorBanner(message: widget.state.error!),
                              const SizedBox(height: AevraSpace.sm),
                            ],
                            if (!isLogin &&
                                widget.state.paymentPending &&
                                widget.state.paymentInfo != null) ...[
                              Text('Payment verification',
                                  style: AevraType.eyebrow()),
                              const SizedBox(height: AevraSpace.sm),
                              Text(
                                  'Scan with GPay, Paytm, BHIM, or any UPI app.',
                                  style: const TextStyle(
                                      color: AevraColors.textSoft)),
                              if (widget.state.paymentInfo!.qrUrl.isNotEmpty)
                                Image.network(widget.state.paymentInfo!.qrUrl,
                                    width: 160, height: 160),
                              Text(
                                  '${widget.state.paymentInfo!.amount} ${widget.state.paymentInfo!.currency}'),
                              Text(widget.state.paymentInfo!.upiId),
                              _Field(
                                  label: 'UTR / transaction reference',
                                  controller: _utr),
                              const SizedBox(height: AevraSpace.sm),
                              SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                      onPressed: widget.state.loading
                                          ? null
                                          : () => widget.state
                                              .submitPayment(_utr.text.trim()),
                                      child:
                                          const Text('Submit payment proof'))),
                              const SizedBox(height: AevraSpace.md),
                            ] else if (!isLogin) ...[
                              _Field(label: 'Your name', controller: _name),
                              const SizedBox(height: AevraSpace.sm),
                              _Field(
                                  label: 'Product or brand name',
                                  controller: _org),
                              const SizedBox(height: AevraSpace.sm),
                              DropdownButtonFormField<String>(
                                initialValue: _accountType,
                                decoration: const InputDecoration(
                                    labelText: 'Account type'),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'creator', child: Text('Creator')),
                                  DropdownMenuItem(
                                      value: 'business',
                                      child: Text('Business')),
                                ],
                                onChanged: (value) => setState(
                                    () => _accountType = value ?? 'creator'),
                              ),
                              const SizedBox(height: AevraSpace.sm),
                            ],
                            _Field(
                                label: 'Email',
                                controller: _email,
                                keyboardType: TextInputType.emailAddress),
                            const SizedBox(height: AevraSpace.sm),
                            _Field(
                                label: 'Password',
                                controller: _password,
                                obscure: true),
                            const SizedBox(height: AevraSpace.lg),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed:
                                    widget.state.loading ? null : _submit,
                                child: widget.state.loading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AevraColors.accentInk),
                                      )
                                    : Text(isLogin ? 'Sign in' : 'Get started'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
      selected: active,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            foregroundColor: active
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant),
        child: Text(label),
      ));
}

class _Field extends StatefulWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.obscure = false,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late bool hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    // Field chrome now comes entirely from `inputDecorationTheme`, so a
    // change to field radius, fill or focus colour lands here and in the
    // command palette at the same time instead of drifting apart.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label.toUpperCase(),
            style: AevraType.eyebrow(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: AevraSpace.xs),
        TextField(
          controller: widget.controller,
          obscureText: hidden,
          keyboardType: widget.keyboardType,
          decoration: InputDecoration(
            labelText: widget.label,
            suffixIcon: widget.obscure
                ? IconButton(
                    tooltip: hidden ? 'Show password' : 'Hide password',
                    icon: Icon(hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => hidden = !hidden),
                  )
                : null,
          ),
          cursorColor: AevraColors.accent,
          style: TextStyle(
              fontSize: 13.5, color: Theme.of(context).colorScheme.onSurface),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AevraSpace.sm, vertical: 10),
      decoration: BoxDecoration(
        color: AevraColors.rose.withValues(alpha: 0.09),
        border: Border.all(color: AevraColors.rose.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(AevraRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 15, color: AevraColors.rose),
          const SizedBox(width: AevraSpace.xs),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  fontSize: 11.5, height: 1.45, color: AevraColors.rose),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthLayout extends StatelessWidget {
  const _AuthLayout({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: LayoutBuilder(
            builder: (context, box) => box.maxWidth >= 800
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children:
                                children.sublist(0, children.length - 1))),
                    const SizedBox(width: 48),
                    Expanded(child: children.last),
                  ])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children)),
      ));
}

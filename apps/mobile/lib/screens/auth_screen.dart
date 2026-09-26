import 'package:lucide_icons_flutter/lucide_icons.dart';
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
  const AuthScreen({
    super.key,
    required this.state,
    this.initialAdminPortal = false,
    this.onToggleTheme,
  });

  final AppState state;
  final bool initialAdminPortal;
  final VoidCallback? onToggleTheme;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool _adminPortal = false;
  final GlobalKey _formKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _org = TextEditingController();
  String _accountType = 'creator';
  final _utr = TextEditingController();

  @override
  void initState() {
    super.initState();
    _adminPortal = widget.initialAdminPortal;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _org.dispose();
    _utr.dispose();
    _scrollController.dispose();
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
      if (_adminPortal &&
          widget.state.user != null &&
          widget.state.user?.isAdmin != true) {
        await widget.state.signOut();
        widget.state
            .reportError('Use an administrator account for this portal.');
      }
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: _adminPortal
          ? (dark ? AevraTheme.adminDark : AevraTheme.adminLight)
          : Theme.of(context),
      child: Builder(builder: _buildPortal),
    );
  }

  void _showForm() {
    final target = _formKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(target,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic);
    }
  }

  void _switchPortal() {
    setState(() {
      _adminPortal = !_adminPortal;
      isLogin = true;
      widget.state.error = null;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic);
    }
  }

  Widget _buildPortal(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final compact = MediaQuery.sizeOf(context).width < 600;
    final light = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      appBar: AppBar(
          centerTitle: false,
          titleSpacing: 16,
          backgroundColor:
              light ? const Color(0xFFF4F3F3) : const Color(0xFF171014),
          title: AevraWordmark(markSize: 28, admin: _adminPortal),
          actions: [
            IconButton(
                onPressed: widget.onToggleTheme,
                tooltip: 'Switch light / dark mode',
                style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: .7),
                    side: BorderSide(color: Theme.of(context).dividerColor)),
                icon: Icon(Theme.of(context).brightness == Brightness.dark
                    ? LucideIcons.sun
                    : LucideIcons.moon)),
            const SizedBox(width: 6),
            OutlinedButton(
                onPressed: () {
                  setState(() => isLogin = true);
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _showForm());
                },
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    backgroundColor: _adminPortal ? accent : null,
                    foregroundColor: _adminPortal
                        ? Theme.of(context).colorScheme.onPrimary
                        : null,
                    shape: const StadiumBorder()),
                child: const Text('Sign in')),
            if (!_adminPortal)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: FilledButton(
                    onPressed: () {
                      setState(() => isLogin = false);
                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => _showForm());
                    },
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 13),
                        shape: const StadiumBorder()),
                    child: const Text('Get started')),
              ),
          ]),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
              child: RepaintBoundary(
                  child: Theme(
            data: _adminPortal ? AevraTheme.adminDark : AevraTheme.dark,
            child: ShaderBackground(admin: _adminPortal),
          ))),
          // The original MOV artwork is optional and never blocks the first
          // frame. LandingVideo fades in only after local codec support is
          // confirmed; ShaderBackground remains the free fallback.
          Positioned.fill(child: LandingVideo(admin: _adminPortal)),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _adminPortal
                        ? const [
                            Color(0xC6070F1E),
                            Color(0x85081428),
                            Color(0xAF070F1E)
                          ]
                        : const [
                            Color(0xC6050508),
                            Color(0x85070508),
                            Color(0xA7050508)
                          ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: AnimatedBuilder(
              animation: widget.state,
              builder: (context, _) {
                return SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(
                      compact ? 24 : AevraSpace.lg,
                      compact ? 34 : AevraSpace.xxl,
                      compact ? 24 : AevraSpace.lg,
                      AevraSpace.xl),
                  child: _AuthLayout(
                    children: [
                      if (!compact) ...[
                        AevraWordmark(
                            markSize: 30, fontSize: 17, admin: _adminPortal),
                        const SizedBox(height: AevraSpace.xxl),
                      ],
                      Text(
                          _adminPortal
                              ? 'VAE ADMINISTRATION'
                              : 'YOUR CREATIVE WORKSPACE',
                          style: AevraType.eyebrow(
                              color: light ? Colors.white : accent)),
                      const SizedBox(height: AevraSpace.sm),
                      Text(
                        _adminPortal
                            ? 'A clear view of\nyour operations.'
                            : 'Your ideas.\nBeautifully made.',
                        style: Theme.of(context)
                            .textTheme
                            .displayMedium
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: AevraSpace.md),
                      Text(
                        _adminPortal
                            ? 'Monitor customer adoption, generation usage, publishing health, and payment approvals.'
                            : 'A quiet space to create media, connect your channels, and share what matters.',
                        style: TextStyle(
                            fontSize: 13.5,
                            height: 1.6,
                            color: const Color(0xFFD4D0D3)),
                      ),
                      if (!compact) const SizedBox(height: AevraSpace.lg),
                      // Match the web hero's Lucide check rail and proof tiles.
                      if (!compact)
                        ...(_adminPortal
                                ? [
                                    'Customer KPIs.',
                                    'Usage insights.',
                                    'Payment review.'
                                  ]
                                : [
                                    'Create media.',
                                    'Connect channels.',
                                    'Publish on schedule.'
                                  ])
                            .map(
                          (point) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: AevraSpace.xs),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(LucideIcons.check,
                                    size: 15,
                                    color: light ? Colors.white : accent),
                                const SizedBox(width: AevraSpace.xs),
                                Expanded(
                                  child: Text(
                                    point,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: const Color(0xFFD4D0D3)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      SizedBox(height: compact ? 22 : AevraSpace.lg),
                      if (compact)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                                border: Border.all(
                                    color: Theme.of(context).dividerColor),
                                borderRadius: BorderRadius.circular(18)),
                            child: Column(children: [
                              _ProofTile(
                                  'One workspace',
                                  _adminPortal
                                      ? 'Complete operational control'
                                      : 'From idea to published post',
                                  grouped: true),
                              Divider(
                                  height: 1,
                                  color: Theme.of(context).dividerColor),
                              _ProofTile(
                                  _adminPortal ? 'Live clarity' : 'AI, refined',
                                  _adminPortal
                                      ? 'Signals that support decisions'
                                      : 'Creative control stays with you',
                                  grouped: true),
                            ]),
                          ),
                        )
                      else
                        Row(children: [
                          Expanded(
                            child: _ProofTile(
                                'One workspace',
                                _adminPortal
                                    ? 'Complete operational control'
                                    : 'From idea to published post'),
                          ),
                          const SizedBox(width: AevraSpace.xs),
                          Expanded(
                            child: _ProofTile(
                                _adminPortal ? 'Live clarity' : 'AI, refined',
                                _adminPortal
                                    ? 'Signals that support decisions'
                                    : 'Creative control stays with you'),
                          ),
                        ]),
                      const SizedBox(height: AevraSpace.xl),
                      // The one surface on this screen, so it gets the top
                      // tier — but no tilt. A tap-down tilt recogniser here
                      // would enter the gesture arena against every TextField
                      // inside it, which risks taps not reliably focusing a
                      // field. Depth on a form isn't worth that.
                      GlassSurface(
                        key: _formKey,
                        elevation: GlassElevation.lifted,
                        radius: 26,
                        padding: const EdgeInsets.all(AevraSpace.lg),
                        borderColor: accent.withValues(alpha: .45),
                        adaptive: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AevraWordmark(
                                markSize: 32,
                                fontSize: 20,
                                admin: _adminPortal),
                            const SizedBox(height: AevraSpace.md),
                            Divider(color: Theme.of(context).dividerColor),
                            const SizedBox(height: AevraSpace.sm),
                            if (!_adminPortal)
                              Row(
                                children: [
                                  _Tab(
                                      label: 'Sign in',
                                      active: isLogin,
                                      onTap: () =>
                                          setState(() => isLogin = true)),
                                  const SizedBox(width: AevraSpace.lg),
                                  _Tab(
                                      label: 'Creator / Business sign up',
                                      active: !isLogin,
                                      onTap: () =>
                                          setState(() => isLogin = false)),
                                ],
                              ),
                            const SizedBox(height: AevraSpace.lg),
                            Text(
                              _adminPortal
                                  ? 'Administrator sign in'
                                  : isLogin
                                      ? 'Welcome back'
                                      : 'Create your VAE account',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: AevraSpace.xs),
                            Text(
                              _adminPortal
                                  ? 'Secure access to customer operations.'
                                  : isLogin
                                      ? 'Your creator workspace starts here.'
                                      : 'Create, publish, and understand in one place.',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 12),
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
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
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
                                    : Text(_adminPortal
                                        ? 'Sign in as administrator'
                                        : isLogin
                                            ? 'Sign in'
                                            : 'Get started'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          onPressed: _switchPortal,
                          icon: Icon(
                              _adminPortal
                                  ? LucideIcons.sparkles
                                  : LucideIcons.shieldCheck,
                              size: 15),
                          label: Text(_adminPortal
                              ? 'Creator sign in'
                              : 'Administrator sign in'),
                        ),
                      ),
                      const SizedBox(height: 42),
                      _LandingStory(admin: _adminPortal),
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

class _ProofTile extends StatelessWidget {
  const _ProofTile(this.title, this.subtitle, {this.grouped = false});

  final String title;
  final String subtitle;
  final bool grouped;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(
            horizontal: grouped ? 20 : AevraSpace.sm,
            vertical: grouped ? 18 : AevraSpace.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(
              alpha:
                  Theme.of(context).brightness == Brightness.light ? .88 : .72),
          border: grouped
              ? null
              : Border.all(color: Theme.of(context).dividerColor),
          borderRadius: grouped ? null : BorderRadius.circular(AevraRadius.lg),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AevraSpace.xxs),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 10.5,
                  height: 1.45,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      );
}

class _LandingStory extends StatelessWidget {
  const _LandingStory({required this.admin});
  final bool admin;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cards = admin
        ? const [
            (
              LucideIcons.layers,
              'See customer health clearly',
              'Follow adoption, workspace activity and publishing outcomes through operational KPIs.'
            ),
            (
              LucideIcons.brainCircuit,
              'Understand product usage',
              'Review aggregate generation activity, model usage and channel performance across customer workspaces.'
            ),
            (
              LucideIcons.shieldCheck,
              'Review with care',
              'Keep payment decisions and account operations in a dedicated administrator workspace.'
            ),
          ]
        : const [
            (
              LucideIcons.sparkles,
              'Make the idea tangible',
              'Turn a brief into images and social copy. Keep your brand references close and bring your own finished assets when you publish.'
            ),
            (
              LucideIcons.layers,
              'Give every visual a voice',
              'Write, generate, or import captions and hashtags. Pair them with an image whenever inspiration arrives.'
            ),
            (
              LucideIcons.calendarDays,
              'Publish with a clear view',
              'Connect your channels, review the complete post, and choose now or later. Follow delivery from one calendar.'
            ),
          ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
          admin
              ? 'CLARITY FOR THE PEOPLE BEHIND THE PLATFORM'
              : 'FROM A SPARK TO A STORY',
          style: AevraType.eyebrow(color: colors.primary)),
      const SizedBox(height: 10),
      Text(
          admin
              ? 'A considered view.\nEvery operation, in context.'
              : 'One thoughtful space.\nEvery part of your creative day.',
          style: Theme.of(context).textTheme.displaySmall),
      const SizedBox(height: 14),
      Text(
          admin
              ? 'Understand customer adoption, publishing health and payment review from one focused operations workspace.'
              : 'Create with intention. Pair the right words and visuals. Find a rhythm your audience can look forward to.',
          style: TextStyle(color: colors.onSurfaceVariant, height: 1.5)),
      const SizedBox(height: 24),
      for (var i = 0; i < cards.length; i++) ...[
        GlassSurface(
          padding: const EdgeInsets.all(22),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(cards[i].$1, color: colors.primary, size: 24),
              const Spacer(),
              Text('${i + 1}'.padLeft(2, '0'),
                  style: TextStyle(
                      color: colors.primary,
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11)),
            ]),
            const SizedBox(height: 20),
            Text(cards[i].$2, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(cards[i].$3,
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.5)),
          ]),
        ),
        const SizedBox(height: 14),
      ],
      const SizedBox(height: 12),
      GlassSurface(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(admin ? LucideIcons.shieldCheck : LucideIcons.brainCircuit,
              color: colors.primary, size: 28),
          const SizedBox(height: 16),
          Text(
              admin
                  ? 'A CALMER WAY TO RUN THE PLATFORM'
                  : '13 TOOLS FOR A MORE INFORMED NEXT MOVE',
              style: AevraType.eyebrow(color: colors.primary)),
          const SizedBox(height: 10),
          Text(
              admin
                  ? 'Good operations start with useful signals.'
                  : 'Let your own history teach you.',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          Text(
              admin
                  ? 'Move between customer KPIs, AI and media usage, publishing analytics and payment review in a dedicated administrator workspace.'
                  : 'Explore content patterns, compare draft predictions, and check the quality of your data. Insights show their limits when there is not enough evidence.',
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.5)),
        ]),
      ),
      const SizedBox(height: 32),
      Text(
          admin
              ? 'VAE · Thoughtful customer operations.'
              : 'VAE · Create. Publish. Understand.',
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
    ]);
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: 32,
            color: active
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
          ),
        ]),
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
                    icon: Icon(hidden ? LucideIcons.eye : LucideIcons.eyeOff),
                    onPressed: () => setState(() => hidden = !hidden),
                  )
                : null,
          ),
          cursorColor: Theme.of(context).colorScheme.primary,
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
    final error = Theme.of(context).colorScheme.error;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AevraSpace.sm, vertical: 10),
      decoration: BoxDecoration(
        color: error.withValues(alpha: 0.09),
        border: Border.all(color: error.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(AevraRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.circleAlert, size: 15, color: error),
          const SizedBox(width: AevraSpace.xs),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 11.5, height: 1.45, color: error),
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

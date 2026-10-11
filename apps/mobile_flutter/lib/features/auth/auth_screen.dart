import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../app/app_controller.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';
import '../avatar/organic_avatar.dart';

class AuthScreen extends StatefulWidget {
  final AppController app;
  const AuthScreen({super.key, required this.app});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}
class _AuthScreenState extends State<AuthScreen> {
  final server = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();

  @override
  void initState() {
    super.initState();
    server.text = widget.app.api.baseUrl;
  }
  @override
  void dispose() {
    server.dispose(); email.dispose(); password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: KColors.bg,
    body: SafeArea(child: AnimatedBuilder(
      animation: widget.app,
      builder: (context, _) {
        final isServer = widget.app.state == StartupState.server;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 32),
          child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 540),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 30),
              const Center(child: OrganicAvatar(size: 138)),
              const SizedBox(height: 48),
              Text(isServer ? 'Connect to Kaka' : 'Welcome back',
                style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(isServer ? 'Enter the address of your personal agent server.'
                : 'Sign in to your self-hosted Kaka workspace.',
                style: const TextStyle(color: KColors.muted, fontSize: 15, height: 1.5)),
              const SizedBox(height: 32),
              if (isServer) KakaField(controller: server,
                label: 'Server URL', hint: 'https://kaka.example.com',
                keyboardType: TextInputType.url)
              else ...[
                KakaField(controller: email, label: 'Email',
                  keyboardType: TextInputType.emailAddress, hint: 'you@example.com'),
                const SizedBox(height: 18),
                KakaField(controller: password, label: 'Password', obscure: true),
              ],
              if (widget.app.error != null) ...[
                const SizedBox(height: 17),
                Text(widget.app.error!, style: const TextStyle(color: KColors.error, fontSize: 13)),
              ],
              const SizedBox(height: 28),
              KakaButton(
                title: isServer ? 'Connect server' : 'Sign in',
                busy: widget.app.busy,
                onPressed: isServer
                  ? () => widget.app.connect(server.text)
                  : () => widget.app.login(email.text, password.text),
              ),
              if (!isServer) ...[
                const SizedBox(height: 20),
                GestureDetector(onTap: () {
                  widget.app.showServerSelection();
                }, child: const Center(child: Text('Change server',
                  style: TextStyle(color: KColors.muted, fontSize: 14)))),
              ],
              const SizedBox(height: 38),
              const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(LucideIcons.shieldCheck, size: 16, color: KColors.muted),
                SizedBox(width: 8),
                Text('Connected to your own server', style: TextStyle(
                  color: KColors.muted, fontSize: 12)),
              ])),
            ]),
          ),
        );
      },
    )),
  );
}

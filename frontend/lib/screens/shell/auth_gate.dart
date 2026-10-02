import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_view.dart';
import '../auth/login_screen.dart';
import 'app_shell.dart';

/// Routes to login or to the app shell depending on session state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        switch (auth.status) {
          case AuthStatus.initializing:
            return const Scaffold(
              body: LoadingView(message: 'Starting…'),
            );
          case AuthStatus.authenticated:
            return AppShell(key: AppShell.navKey);
          case AuthStatus.unauthenticated:
            return const LoginScreen();
        }
      },
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:trace_it/screens/splash_screen.dart';
import 'package:trace_it/screens/home_page.dart';
import 'package:trace_it/screens/get_started_page.dart';
import 'package:trace_it/screens/login_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _loggedIn = false;

  bool _hasLoggedInOnce = false;

  StreamSubscription<AuthState>? _authSub;

  void _sync() {
    final session = Supabase.instance.client.auth.currentSession;
    _loggedIn = session != null;
    _loading = false;
  }

  @override
  void initState() {
    super.initState();
    _sync();

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;

      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        _hasLoggedInOnce = true;
      }

      setState(_sync);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SplashScreen();
    if (_loggedIn) return const HomePage();

    return _hasLoggedInOnce ? const LoginPage() : const GetStartedPage();
  }
}

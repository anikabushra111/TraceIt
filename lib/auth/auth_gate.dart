import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:trace_it/screens/splash_screen.dart';
import 'package:trace_it/screens/home_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _loggedIn = false;
  bool _emailVerified = false;
  StreamSubscription<AuthState>? _authSub;

  void _sync() {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    final user = client.auth.currentUser;

    _loggedIn = session != null;
    _emailVerified = (user?.emailConfirmedAt != null);
    _loading = false;
  }

  @override
  void initState() {
    super.initState();

    _sync();

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
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

    // Only enter the app if session exists AND email is verified.
    if (_loggedIn && _emailVerified) {
      return const HomePage();
    }

    // Not logged in OR not verified yet -> stay in auth flow (your Splash -> GetStarted/Login)
    return const SplashScreen();
  }
}

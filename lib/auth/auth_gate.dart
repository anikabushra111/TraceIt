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
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();

    final client = Supabase.instance.client;

    // 1) Check current session once when the app starts
    final session = client.auth.currentSession;
    _loggedIn = session != null;
    _loading = false;

    // 2) Listen for later sign-in / sign-out changes
    _authSub = client.auth.onAuthStateChange.listen((data) {
      final session = data.session;

      if (!mounted) return;

      setState(() {
        _loggedIn = session != null;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SplashScreen();
    }

    if (_loggedIn) {
      return const HomePage();
    }

    // Keep your Splash behavior exactly the same:
    // Splash waits 3 seconds and goes to GetStarted/Login flow.
    return const SplashScreen();
  }
}

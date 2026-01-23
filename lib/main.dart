import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:trace_it/auth/auth_gate.dart';
import 'package:trace_it/screens/reset_password_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://kmjiqresukbemgatesxr.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImttamlxcmVzdWtiZW1nYXRlc3hyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQyNTEzNjksImV4cCI6MjA3OTgyNzM2OX0.JSabellxOIEYEtUJ22xZbEC36xqKeCN2phF6D94dtdM',
  );

  runApp(const TraceItApp());
}

class TraceItApp extends StatefulWidget {
  const TraceItApp({super.key});

  @override
  State<TraceItApp> createState() => _TraceItAppState();
}

class _TraceItAppState extends State<TraceItApp> {
  static const primaryNavy = Color(0xFF1F3A93);

  final _navKey = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _authSub;

  bool _recoveryScreenOpen = false;

  @override
  void initState() {
    super.initState();

    final supabase = Supabase.instance.client;

    _authSub = supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;

      // Handle recovery only here (NOT in AuthGate).
      if (event == AuthChangeEvent.passwordRecovery) {
        if (_recoveryScreenOpen) return;
        _recoveryScreenOpen = true;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          final nav = _navKey.currentState;
          if (nav == null) return;

          nav
              .push(
                MaterialPageRoute(
                  builder: (_) => ResetPasswordPage(
                    onDone: () {
                      _recoveryScreenOpen = false;

                      nav.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const AuthGate()),
                        (route) => false,
                      );
                    },
                  ),
                ),
              )
              .then((_) {
                // If user presses back, allow recovery screen to open again later.
                _recoveryScreenOpen = false;
              });
        });
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navKey,
      title: 'TraceIt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        primaryColor: primaryNavy,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryNavy,
          primary: primaryNavy,
          secondary: primaryNavy,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryNavy,
            foregroundColor: Colors.white,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: primaryNavy),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: primaryNavy,
          selectionColor: Color(0x331F3A93),
          selectionHandleColor: primaryNavy,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

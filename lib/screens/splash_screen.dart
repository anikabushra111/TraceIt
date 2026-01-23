import 'dart:async';
import 'package:flutter/material.dart';
import 'get_started_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GetStartedPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon card (similar style to your PDF/onboarding)
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FF),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: const Icon(
                    Icons.gps_fixed_rounded,
                    size: 64,
                    color: Color(0xFF2956FF),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'TraceIt',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),

                const SizedBox(height: 4),
                Text(
                  'Built to find and return',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: const Color(
                      0xFF111827,
                    ).withOpacity(0.6), // Lighter subtitle
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

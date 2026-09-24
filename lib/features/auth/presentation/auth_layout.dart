import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Centered card layout shared by the login, reset and setup screens.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  Image.asset('assets/branding/logo_full.png', height: 150),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(title, style: t.titleLarge, textAlign: TextAlign.center),
                          if (subtitle != null) ...[
                            const SizedBox(height: 6),
                            Text(subtitle!,
                                style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
                                textAlign: TextAlign.center),
                          ],
                          const SizedBox(height: 22),
                          child,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Alfardos Management', style: t.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

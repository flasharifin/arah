import 'package:flutter/material.dart';

/// Tampil singkat saat sesi sedang diperiksa.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Image(image: AssetImage('assets/images/arah-logo.png'), width: 160)),
    );
  }
}

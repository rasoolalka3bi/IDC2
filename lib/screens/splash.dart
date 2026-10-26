import 'package:flutter/material.dart';

import '../app/theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.brand,
      body: Center(
        child: Container(
          width: 110,
          height: 110,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32)),
          child: Image.asset('assets/images/logo.png'),
        ),
      ),
    );
  }
}

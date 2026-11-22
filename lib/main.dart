import 'package:flutter/material.dart';

import 'ui/calculator_screen.dart';

void main() => runApp(const WCalcApp());

class WCalcApp extends StatelessWidget {
  const WCalcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'W-Calc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2B2F3A)),
      ),
      home: const CalculatorScreen(),
    );
  }
}

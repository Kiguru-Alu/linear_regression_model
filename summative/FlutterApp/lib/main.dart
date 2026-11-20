import 'package:flutter/material.dart';

import 'prediction_page.dart';
import 'risk_api.dart';
import 'theme.dart';

void main() {
  runApp(HectareAfricaApp(api: RiskApi()));
}

class HectareAfricaApp extends StatelessWidget {
  const HectareAfricaApp({super.key, required this.api});

  final RiskApi api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hectare Africa',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: PredictionPage(api: api),
    );
  }
}

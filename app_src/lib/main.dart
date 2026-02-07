import 'package:flutter/material.dart';
import 'features/home/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TorrDistributionApp());
}

class TorrDistributionApp extends StatelessWidget {
  const TorrDistributionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Torr Distribution',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

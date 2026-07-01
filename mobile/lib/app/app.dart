import 'package:flutter/material.dart';

class SnapSyncApp extends StatelessWidget {
  const SnapSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SnapSync AI',
      home: Scaffold(
        body: Center(
          child: Text(
            'SnapSync AI',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

/// Placeholder for Module 2.1's Interactive Destination Map (color-coded
/// category markers, clustering, popups) — awaiting its detailed mockup.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'The interactive destination map is coming soon.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

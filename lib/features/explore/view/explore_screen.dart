import 'package:flutter/material.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Explore is coming soon — send over the mockup and this screen '
            'will be built to match it.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

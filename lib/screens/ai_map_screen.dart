import 'package:flutter/material.dart';

class AiMapScreen extends StatefulWidget {
  const AiMapScreen({super.key});

  @override
  State<AiMapScreen> createState() => _AiMapScreenState();
}

class _AiMapScreenState extends State<AiMapScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI地图'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'AI地图功能',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '此功能正在开发中...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class PolicyView extends StatelessWidget {
  final String title;
  final String content;

  const PolicyView({Key? key, required this.title, required this.content}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCF0),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF4A2C2A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class AppCredits extends StatelessWidget {
  const AppCredits({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        SizedBox(height: 20),
        Text(
          'Homi Labs',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Code with Purpose, build with heart',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 10),
        Text(
          'Developed by Homi Labs Team',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Awaiz Fatima • Abdulhadi • Parishay Zainab',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

class TransferProgress extends StatelessWidget {
  final double progress;
  
  const TransferProgress({
    Key? key,
    required this.progress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).toInt();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
        const SizedBox(height: 4),
        Text(
          '$percentage% complete',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }
}

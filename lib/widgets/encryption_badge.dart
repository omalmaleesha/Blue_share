import 'package:flutter/material.dart';

class EncryptionBadge extends StatelessWidget {
  final bool isEncrypted;
  final bool mini;
  
  const EncryptionBadge({
    Key? key,
    required this.isEncrypted,
    this.mini = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isEncrypted) return const SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: mini ? 6.0 : 8.0,
        vertical: mini ? 2.0 : 4.0,
      ),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.9),
        borderRadius: BorderRadius.circular(mini ? 4.0 : 8.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock,
            color: Colors.white,
            size: mini ? 12.0 : 16.0,
          ),
          SizedBox(width: mini ? 2.0 : 4.0),
          Text(
            mini ? 'Secure' : 'Encrypted',
            style: TextStyle(
              color: Colors.white,
              fontSize: mini ? 10.0 : 12.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

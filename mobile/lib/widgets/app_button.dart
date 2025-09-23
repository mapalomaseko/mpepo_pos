import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;

  const AppButton({super.key, required this.label, this.onPressed, this.isPrimary = true});

  @override
  Widget build(BuildContext context) {
    final buttonStyle = ElevatedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
    );
    final child = Text(label.toUpperCase());

    if (isPrimary) {
      return ElevatedButton(onPressed: onPressed, style: buttonStyle, child: child);
    }
    return OutlinedButton(onPressed: onPressed, style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)), child: child);
  }
}

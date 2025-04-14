// lib/widgets/error_banner.dart
import 'package:flutter/material.dart';

class ErrorBanner extends StatelessWidget {
  final String errorMessage;
  final VoidCallback? onRetry;
  final Color backgroundColor;
  final Color textColor;
  final IconData icon;

  const ErrorBanner({
    super.key,
    required this.errorMessage,
    this.onRetry,
    this.backgroundColor = Colors.red,
    this.textColor = Colors.white,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              errorMessage,
              style: TextStyle(color: textColor),
            ),
          ),
          if (onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh, color: textColor),
              label: Text('Retry', style: TextStyle(color: textColor)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
        ],
      ),
    );
  }
}

class NetworkErrorBanner extends StatelessWidget {
  final VoidCallback? onRetry;

  const NetworkErrorBanner({
    super.key,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorBanner(
      errorMessage: 'Unable to connect to Google Maps. Please check your internet connection.',
      backgroundColor: Colors.red.shade800,
      onRetry: onRetry,
      icon: Icons.wifi_off,
    );
  }
}

class ApiKeyErrorBanner extends StatelessWidget {
  final VoidCallback? onRetry;

  const ApiKeyErrorBanner({
    super.key,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorBanner(
      errorMessage: 'API key error. Please check your Google Maps configuration.',
      backgroundColor: Colors.orange.shade800,
      onRetry: onRetry,
      icon: Icons.vpn_key,
    );
  }
}
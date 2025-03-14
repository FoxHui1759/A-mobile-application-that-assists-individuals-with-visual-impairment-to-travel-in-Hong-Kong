// lib/utils/connectivity_checker.dart
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityChecker {
  // Singleton instance
  static final ConnectivityChecker _instance = ConnectivityChecker._internal();
  factory ConnectivityChecker() => _instance;
  ConnectivityChecker._internal();

  // Check if device has internet connection
  Future<bool> isConnected() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return false;
    }

    // Double check with a real server ping
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  // Show no internet connection dialog
  Future<void> showNoInternetDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('No Internet Connection'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Please check your internet connection and try again.'),
                SizedBox(height: 10),
                Text(
                  'The app requires internet access to use Google Maps services.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Check Again'),
              onPressed: () async {
                if (await isConnected()) {
                  Navigator.of(context).pop();
                } else {
                  // Show a snackbar indicating still no connection
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Still no internet connection. Please check your settings.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Show API connection error dialog
  Future<void> showApiConnectionErrorDialog(BuildContext context, String errorMessage) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Connection Error'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('Unable to connect to Google Maps services.'),
                const SizedBox(height: 10),
                Text(
                  errorMessage,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                const Text(
                  'This may be due to a network issue or an API key problem.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Try Again'),
              onPressed: () {
                Navigator.of(context).pop(true); // Return true to indicate retry
              },
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false); // Return false to indicate cancel
              },
            ),
          ],
        );
      },
    );
  }
}
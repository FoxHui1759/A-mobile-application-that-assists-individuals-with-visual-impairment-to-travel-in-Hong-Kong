import 'package:flutter/material.dart';

class MessageBox extends StatelessWidget {
  final String message;
  const MessageBox({Key? key, required this.message}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 10.0),
      width: double.infinity,
      height: 100,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

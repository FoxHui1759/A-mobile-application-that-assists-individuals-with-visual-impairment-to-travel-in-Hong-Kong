import 'package:flutter/material.dart';

class MicPopup extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: Colors.black.withAlpha((0.5 * 255).round()),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.mic, size: 100, color: Colors.white),
                Text('Listening...',
                    style: Theme.of(context).textTheme.bodyLarge),
                SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'pages/camera_page.dart';
import 'pages/microphone_page.dart';
import 'pages/settings_page.dart';

class HomePage extends StatefulWidget {
  final String title;

  HomePage({required this.title});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    CameraPage(),
    MicrophonePage(),
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              AppBar(
                centerTitle: true,
                backgroundColor: Theme.of(context).primaryColor,
                title: Text(
                  "Going to: The Unisersity of Hong Kong",
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              Container(
                color: Theme.of(context).primaryColor,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      'Keep Forward',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '50 mins',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              )
            ],
          )),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).primaryColor,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.camera, color: Colors.white),
            label: 'Camera',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mic, color: Colors.white),
            label: 'Microphone',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings, color: Colors.white),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.white,
        onTap: _onItemTapped,
      ),
    );
  }
}

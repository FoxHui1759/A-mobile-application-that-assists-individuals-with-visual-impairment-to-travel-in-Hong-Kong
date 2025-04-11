import 'package:eyes_on_the_road/views/camera_view.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  final String title;

  HomePage({required this.title});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: Theme.of(context).primaryColor,
          title: Text(
            widget.title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        body: Center(child: CameraView()),
        bottomNavigationBar: BottomAppBar(
          color: Theme.of(context).primaryColor,
          child: SizedBox(
            height: 0,
          ),
        ));
  }
}

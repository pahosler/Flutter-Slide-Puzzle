import 'package:flutter_web/material.dart';
import 'package:flutter_slide_puzzle_hummingbird/puzzle.dart';
import 'dart:math';

var now = new DateTime.now();
Random rnd = new Random(now.millisecondsSinceEpoch);

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Slide Puzzle',
      theme: ThemeData(
        primaryColor: Colors.cyan[200],
      ),
      home: Puzzle(title: 'Flutter Slide Puzzle'),
    );
  }
}

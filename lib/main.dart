import 'package:flutter/material.dart';
import 'package:flutter_slide_puzzle/puzzle.dart';
import 'dart:math';

var now = new DateTime.now();
Random rnd = new Random(now.millisecondsSinceEpoch);

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primaryColor: Colors.cyan[200],
      ),
      home: Puzzle(title: 'Flutter Slide Puzzle'),
    );
  }
}

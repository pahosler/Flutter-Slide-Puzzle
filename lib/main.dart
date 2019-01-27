import 'package:flutter/material.dart';
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
        primarySwatch: Colors.cyan,
        primaryColor: Colors.cyan[200],
      ),
      home: Puzzle(title: 'Flutter Slide Puzzle'),
    );
  }
}

class Puzzle extends StatefulWidget {
  Puzzle({Key key, this.title}) : super(key: key);
  final String title;
  @override
  _PuzzleState createState() => _PuzzleState();
}

class _PuzzleState extends State<Puzzle> {
  final nums = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 0];
  final white = Colors.white70;
  List<int> scrambled = [];
  var _green = Colors.greenAccent;
  bool _scrambled = true;
  int min = 0, max = 16;

  void scramble() {
    int num = rnd.nextInt(max);
    if (scrambled.length == nums.length) {
      return;
    }

    if (scrambled.contains(num)) {
      scramble();
    } else {
      scrambled.add(num);
    }

    if (scrambled.length < nums.length) {
      scramble();
    }
  }

  void moveTile(tileClicked) {
    int blankTile = scrambled.indexOf(0);
    int selectedTile = scrambled.indexOf(tileClicked);
    if (tileClicked == 0) {
      return;
    }
    if (blankTile == 3 && selectedTile == 4) {
      return;
    } else if (blankTile == 7 && selectedTile == 8) {
      return;
    } else if (blankTile == 11 && selectedTile == 12) {
      return;
    } else if (blankTile == 4 && selectedTile == 3) {
      return;
    } else if (blankTile == 8 && selectedTile == 7) {
      return;
    } else if (blankTile == 12 && selectedTile == 11) {
      return;
    } else if (selectedTile - 4 == blankTile ||
        selectedTile + 4 == blankTile ||
        selectedTile - 1 == blankTile ||
        selectedTile + 1 == blankTile) {
      setState(() {
        scrambled[selectedTile] = 0;
        scrambled[blankTile] = tileClicked;
      });
    } else {
      return;
    }
  }

  void changeColor() {
    setState(() {
      _green = Colors.pinkAccent;
    });
  }

  Widget gamecell(context, num) {
    bool isBlank = num == 0;
    return GestureDetector(
      onTap: () {
        // changeColor();
        moveTile(num);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isBlank ? white : _green,
          border: Border.all(),
        ),
        child: Center(
          child: Text(
            "${isBlank ? ' ' : num}",
            style: Theme.of(context).textTheme.headline,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    scramble();
    return Scaffold(
      backgroundColor: Colors.blue[100],
      appBar: AppBar(
        title: Center(child: Text(widget.title)),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Container(
              padding: EdgeInsets.all(10.0),
              margin: EdgeInsets.all(10.0),
              child: GridView.count(
                crossAxisCount: 4,
                crossAxisSpacing: 5.0,
                mainAxisSpacing: 5.0,
                children: List.generate(scrambled.length, (index) {
                  return gamecell(context, scrambled[index]);
                }),
              ),
            ),
          ),
          Center(
            child: Container(
              padding: EdgeInsets.all(10.0),
              child: RaisedButton(
                highlightElevation: 6.0,
                color: Colors.lightBlueAccent,
                splashColor: Colors.blue[100],
                onPressed: (() {
                  scrambled.clear();
                  setState(() {
                    _scrambled = !_scrambled;
                  });
                  scramble();
                }),
                child: Text('Click to Scramble!'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

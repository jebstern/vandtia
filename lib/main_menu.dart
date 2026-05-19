import "dart:async";

import "package:flutter/material.dart";
import "game_screen.dart";

class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade900,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              "Vändtia",
              style: TextStyle(
                color: Colors.white,
                fontSize: 64,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 16,
                ),
              ),
              onPressed: () {
                unawaited(
                  Navigator.of(context).push(
                    MaterialPageRoute<Object?>(
                      builder: (BuildContext context) => const GameScreen(),
                    ),
                  ),
                );
              },
              child: const Text("New Game", style: TextStyle(fontSize: 24)),
            ),
          ],
        ),
      ),
    );
  }
}

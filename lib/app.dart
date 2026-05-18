import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/game.dart';
import 'game/vandtia_game.dart';
import 'features/game/providers/game_provider.dart';
import 'features/game/domain/game_state.dart';

class VandtiaApp extends ConsumerWidget {
  const VandtiaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Vändtia',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const MainMenu(),
    );
  }
}

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
          children: [
            const Text(
              'Vändtia',
              style: TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16)),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const GameScreen()));
              },
              child: const Text('New Game', style: TextStyle(fontSize: 24)),
            ),
          ],
        ),
      ),
    );
  }
}

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late VandtiaGame _game;

  @override
  void initState() {
    super.initState();
    _game = VandtiaGame(ref);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameStateProvider);

    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: _game),

          // UI Overlays
          if (state.phase == GamePhase.rearrangement && !state.players[0].isReady)
            Positioned(
              bottom: 100,
              right: 20,
              child: ElevatedButton(
                onPressed: () => ref.read(gameStateProvider.notifier).finishRearrangement(),
                child: const Text('Finish Rearrangement'),
              ),
            ),

          Positioned(
            top: 40,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.black54,
                  child: Text(
                    'Turn: ${state.currentPlayer.name}${state.currentPlayer.isBot ? " (Bot)" : ""}',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
                if (ref.read(gameStateProvider.notifier).errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    color: Colors.red.withOpacity(0.8),
                    child: Text(
                      ref.read(gameStateProvider.notifier).errorMessage!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),

          if (state.phase == GamePhase.playing && state.currentPlayerIndex == 0)
            Positioned(
              bottom: 20,
              right: 20,
              child: ElevatedButton(
                onPressed: () => ref.read(gameStateProvider.notifier).pickUpPile(),
                child: const Text('Pick up pile'),
              ),
            ),

          if (state.phase == GamePhase.gameOver)
            Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Game Over! ${state.winnerId == state.players[0].id ? "You Win!" : "Bot Wins!"}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => ref.read(gameStateProvider.notifier).restartGame(),
                      child: const Text('Play Again'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

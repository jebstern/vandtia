import "dart:async";

import "package:flame/game.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "features/game/domain/game_state.dart";
import "features/game/providers/game_provider.dart";
import "game/vandtia_game.dart";

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
    final GameState state = ref.watch(gameStateProvider);

    final PlayerModel current = state.currentPlayer;
    final String turnLabel =
        'Turn: ${current.name}${current.isBot ? " (Bot)" : ""}';
    final bool humanWon = state.winnerId == state.players[0].id;
    final String gameOverLabel =
        'Game Over! ${humanWon ? "You Win!" : "Bot Wins!"}';

    return Scaffold(
      body: Stack(
        children: <Widget>[
          GameWidget<VandtiaGame>(game: _game),

          // UI Overlays
          if (state.phase == GamePhase.rearrangement &&
              !state.players[0].isReady)
            Positioned(
              top: 100,
              right: 20,
              child: ElevatedButton(
                onPressed: () =>
                    ref.read(gameStateProvider.notifier).finishRearrangement(),
                child: const Text("Finish Rearrangement"),
              ),
            ),

          Positioned(
            top: 40,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.black54,
                  child: Text(
                    turnLabel,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
                if (ref.read(gameStateProvider.notifier).errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    color: Colors.red.withValues(alpha: 0.8),
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
                onPressed: () =>
                    ref.read(gameStateProvider.notifier).pickUpPile(),
                child: const Text("Pick up pile"),
              ),
            ),

          // Flashing "Chance" badge over the stock pile: shown whenever the
          // current player (human or bot) is stuck and may flip a stock card.
          if (ref.read(gameStateProvider.notifier).chanceAvailable)
            Positioned(
              left: 50,
              top: MediaQuery.sizeOf(context).height / 2 - 45,
              width: 70,
              height: 100,
              child: _ChanceBadge(
                onTap: state.currentPlayerIndex == 0
                    ? () =>
                          ref.read(gameStateProvider.notifier).playChanceCard()
                    : null,
              ),
            ),

          if (state.phase == GamePhase.gameOver)
            Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                color: Colors.white,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      gameOverLabel,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () =>
                          ref.read(gameStateProvider.notifier).restartGame(),
                      child: const Text("Play Again"),
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

/// A pulsing "CHANCE" badge drawn over the stock pile. Tappable only when
/// [onTap] is provided (the human's turn); otherwise it just flashes.
class _ChanceBadge extends StatefulWidget {
  const _ChanceBadge({this.onTap});

  final VoidCallback? onTap;

  @override
  State<_ChanceBadge> createState() => _ChanceBadgeState();
}

class _ChanceBadgeState extends State<_ChanceBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    unawaited(_controller.repeat(reverse: true));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.35, end: 1).animate(_controller),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange, width: 3),
          ),
          child: const Text(
            "CHANCE",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

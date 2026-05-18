import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/game_state.dart';
import '../domain/vandtia_logic.dart';
import '../domain/card_models.dart';

class GameNotifier extends Notifier<GameState> {
  @override
  GameState build() {
    return VandtiaLogic.initialState(['Player', 'Bot'], isBot: [false, true]);
  }

  String? errorMessage;

  void playCards(List<CardModel> cards) {
    if (!VandtiaLogic.canPlayCards(cards, state.playPile)) {
       errorMessage = "Cannot play those cards!";
       state = state.copyWith(); // Trigger rebuild to show error
       return;
    }
    errorMessage = null;
    state = VandtiaLogic.playCards(state, cards);
    _checkBotTurn();
  }

  void playFaceDownCard(CardModel card) {
    state = VandtiaLogic.playFaceDownCard(state, card);
    _checkBotTurn();
  }

  void pickUpPile() {
    state = VandtiaLogic.pickUpPile(state);
    _checkBotTurn();
  }

  void swapCards(CardModel handCard, CardModel faceUpCard) {
    state = VandtiaLogic.swapCards(state, state.currentPlayerIndex, handCard, faceUpCard);
  }

  void finishRearrangement() {
    state = VandtiaLogic.setPlayerReady(state, state.currentPlayerIndex);
    _checkBotTurn();
  }

  void restartGame() {
    state = VandtiaLogic.initialState(['Player', 'Bot'], isBot: [false, true]);
  }

  void _checkBotTurn() async {
    if (state.phase == GamePhase.gameOver) return;

    if (state.phase == GamePhase.rearrangement) {
      // Bot is always ready in this MVP for simplicity
      return;
    }

    if (state.currentPlayer.isBot) {
      // Small delay for realism
      await Future.delayed(const Duration(milliseconds: 1000));
      _performBotMove();
    }
  }

  void _performBotMove() {
    final bot = state.currentPlayer;

    // 1. Try playing from hand
    if (bot.hand.isNotEmpty) {
      final playable = _getPlayableFromList(bot.hand);
      if (playable.isNotEmpty) {
        playCards(playable);
        return;
      }
    }
    // 2. Try playing from face-up
    else if (bot.faceUp.isNotEmpty) {
      final playable = _getPlayableFromList(bot.faceUp);
      if (playable.isNotEmpty) {
        playCards(playable);
        return;
      }
    }
    // 3. Try playing from face-down
    else if (bot.faceDown.isNotEmpty) {
      // Bot picks a random face-down card
      playFaceDownCard(bot.faceDown.first);
      return;
    }

    // 4. Must pick up if no hand/face-up cards are playable
    if (bot.hand.isNotEmpty || bot.faceUp.isNotEmpty) {
      pickUpPile();
    }
  }

  List<CardModel> _getPlayableFromList(List<CardModel> cards) {
    // Basic AI: Play lowest valid card, prefer non-special
    final validCards = cards.where((c) => VandtiaLogic.canPlayCards([c], state.playPile)).toList();
    if (validCards.isEmpty) return [];

    validCards.sort((a, b) => a.rank.value.compareTo(b.rank.value));

    // Try to find lowest non-special (not 2 or 10)
    final normal = validCards.where((c) => c.rank != Rank.two && c.rank != Rank.ten).toList();
    if (normal.isNotEmpty) {
      // Check for multiples of the same rank
      final firstRank = normal.first.rank;
      return normal.where((c) => c.rank == firstRank).toList();
    }

    // Play special card if no normal cards
    return [validCards.first];
  }
}

final gameStateProvider = NotifierProvider<GameNotifier, GameState>(() {
  return GameNotifier();
});

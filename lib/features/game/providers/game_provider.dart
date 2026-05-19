import "dart:async";

import "package:flutter_riverpod/flutter_riverpod.dart";

import "../domain/card_models.dart";
import "../domain/game_state.dart";
import "../domain/vandtia_logic.dart";

class GameNotifier extends Notifier<GameState> {
  @override
  GameState build() {
    return VandtiaLogic.initialState(
      <String>["Player", "Bot"],
      isBot: <bool>[false, true],
    );
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
    unawaited(_checkBotTurn());
  }

  void playFaceDownCard(CardModel card) {
    state = VandtiaLogic.playFaceDownCard(state, card);
    unawaited(_checkBotTurn());
  }

  void pickUpPile() {
    state = VandtiaLogic.pickUpPile(state);
    unawaited(_checkBotTurn());
  }

  /// Flip the top stock card as a "chance" card when the player is stuck.
  void playChanceCard() {
    state = VandtiaLogic.playChanceCard(state);
    unawaited(_checkBotTurn());
  }

  /// Endgame: take a face-up card into the hand to play it from there.
  void pickUpFaceUpCard(CardModel card) {
    state = VandtiaLogic.pickUpFaceUpCard(state, card);
    unawaited(_checkBotTurn());
  }

  /// True when the current player has no valid move and may flip a chance
  /// card from the stock.
  bool get chanceAvailable =>
      state.phase == GamePhase.playing &&
      state.stock.isNotEmpty &&
      !VandtiaLogic.currentPlayerHasMove(state);

  void swapCards(CardModel handCard, CardModel faceUpCard) {
    // Rearrangement is always the human player (index 0);
    // the bot is auto-ready.
    state = VandtiaLogic.swapCards(state, 0, handCard, faceUpCard);
  }

  void finishRearrangement() {
    state = VandtiaLogic.setPlayerReady(state, 0);
    unawaited(_checkBotTurn());
  }

  void restartGame() {
    state = VandtiaLogic.initialState(
      <String>["Player", "Bot"],
      isBot: <bool>[false, true],
    );
  }

  Future<void> _checkBotTurn() async {
    if (state.phase == GamePhase.gameOver) {
      return;
    }

    if (state.phase == GamePhase.rearrangement) {
      // Bot is always ready in this MVP for simplicity
      return;
    }

    if (state.currentPlayer.isBot) {
      // Small delay for realism
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      _performBotMove();
    }
  }

  void _performBotMove() {
    final PlayerModel bot = state.currentPlayer;

    // 1. Try playing from hand
    if (bot.hand.isNotEmpty) {
      final List<CardModel> playable = _getPlayableFromList(bot.hand);
      if (playable.isNotEmpty) {
        playCards(playable);
        return;
      }
    }
    // 2. Hand empty: take a playable face-up card into the hand. The bot
    //    plays it from the hand on its next move (the turn does not change).
    else if (bot.faceUp.isNotEmpty) {
      final List<CardModel> playable = _getPlayableFromList(bot.faceUp);
      if (playable.isNotEmpty) {
        pickUpFaceUpCard(playable.first);
        return;
      }
    }
    // 3. Try playing from face-down
    else if (bot.faceDown.isNotEmpty) {
      // Bot picks a random face-down card
      playFaceDownCard(bot.faceDown.first);
      return;
    }

    // 4. Stuck: gamble with a chance card from the stock, else pick up.
    if (bot.hand.isNotEmpty || bot.faceUp.isNotEmpty) {
      if (state.stock.isNotEmpty) {
        playChanceCard();
      } else {
        pickUpPile();
      }
    }
  }

  List<CardModel> _getPlayableFromList(List<CardModel> cards) {
    // Basic AI: Play lowest valid card, prefer non-special
    final List<CardModel> validCards = cards
        .where(
          (CardModel c) =>
              VandtiaLogic.canPlayCards(<CardModel>[c], state.playPile),
        )
        .toList();
    if (validCards.isEmpty) {
      return <CardModel>[];
    }

    validCards.sort(
      (CardModel a, CardModel b) => a.rank.value.compareTo(b.rank.value),
    );

    // Try to find lowest non-special (not 2 or 10)
    final List<CardModel> normal = validCards
        .where((CardModel c) => c.rank != Rank.two && c.rank != Rank.ten)
        .toList();
    if (normal.isNotEmpty) {
      // Check for multiples of the same rank
      final Rank firstRank = normal.first.rank;
      return normal.where((CardModel c) => c.rank == firstRank).toList();
    }

    // Play special card if no normal cards
    return <CardModel>[validCards.first];
  }
}

final NotifierProvider<GameNotifier, GameState> gameStateProvider =
    NotifierProvider<GameNotifier, GameState>(() {
      return GameNotifier();
    });

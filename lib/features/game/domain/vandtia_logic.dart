// ignore_for_file: avoid_classes_with_only_static_members

import "dart:math";

import "card_models.dart";
import "game_state.dart";

class VandtiaLogic {
  static List<CardModel> createDeck() {
    final List<CardModel> deck = <CardModel>[];
    for (final Suit suit in Suit.values) {
      for (final Rank rank in Rank.values) {
        deck.add(CardModel(suit: suit, rank: rank));
      }
    }
    return deck..shuffle();
  }

  static GameState initialState(List<String> playerNames, {List<bool>? isBot}) {
    final List<CardModel> deck = createDeck();
    final List<PlayerModel> players = <PlayerModel>[];
    int deckIndex = 0;

    for (int i = 0; i < playerNames.length; i++) {
      final List<CardModel> faceDown = deck.sublist(deckIndex, deckIndex + 3);
      deckIndex += 3;
      final List<CardModel> faceUp = deck.sublist(deckIndex, deckIndex + 3);
      deckIndex += 3;
      final List<CardModel> hand = deck.sublist(deckIndex, deckIndex + 3);
      deckIndex += 3;

      players.add(
        PlayerModel(
          id: "player_$i",
          name: playerNames[i],
          hand: hand,
          faceUp: faceUp,
          faceDown: faceDown,
          isBot: isBot?[i] ?? false,
        ),
      );
    }

    final int dealerIndex = Random().nextInt(players.length);
    final int currentPlayerIndex = (dealerIndex + 1) % players.length;

    return GameState(
      players: players,
      currentPlayerIndex: currentPlayerIndex,
      stock: deck.sublist(deckIndex),
      playPile: <CardModel>[],
      burnedPile: <CardModel>[],
      phase: GamePhase.rearrangement,
      dealerIndex: dealerIndex,
    );
  }

  static bool canPlayCards(List<CardModel> cards, List<CardModel> playPile) {
    if (cards.isEmpty) {
      return false;
    }
    final Rank rank = cards.first.rank;
    // All cards in a play must have the same rank
    if (!cards.every((CardModel c) => c.rank == rank)) {
      return false;
    }

    if (playPile.isEmpty) {
      return true;
    }

    if (rank == Rank.two || rank == Rank.ten) {
      return true;
    }

    final Rank topRank = playPile.last.rank;
    return rank.value >= topRank.value;
  }

  static GameState playCards(GameState state, List<CardModel> cards) {
    if (!canPlayCards(cards, state.playPile)) {
      throw Exception("Invalid move");
    }

    final PlayerModel currentPlayer = state.currentPlayer;
    final List<CardModel> newHand = List<CardModel>.from(currentPlayer.hand);
    final List<CardModel> newFaceUp = List<CardModel>.from(
      currentPlayer.faceUp,
    );
    final List<CardModel> newFaceDown = List<CardModel>.from(
      currentPlayer.faceDown,
    );

    // Identify where cards are played from
    for (final CardModel card in cards) {
      if (newHand.contains(card)) {
        newHand.remove(card);
      } else if (newFaceUp.contains(card)) {
        newFaceUp.remove(card);
      } else if (newFaceDown.contains(card)) {
        newFaceDown.remove(card);
      }
    }

    final List<CardModel> newPlayPile = List<CardModel>.from(state.playPile)
      ..addAll(cards);

    // Check for burn (10 or four-of-a-kind)
    bool shouldBurn = false;
    if (cards.any((CardModel c) => c.rank == Rank.ten)) {
      shouldBurn = true;
    } else if (newPlayPile.length >= 4) {
      final List<CardModel> lastFour = newPlayPile.sublist(
        newPlayPile.length - 4,
      );
      if (lastFour.every((CardModel c) => c.rank == lastFour.first.rank)) {
        shouldBurn = true;
      }
    }

    GameState nextState = state.copyWith(
      playPile: newPlayPile,
      players: _updatePlayerInList(
        state.players,
        state.currentPlayerIndex,
        currentPlayer.copyWith(
          hand: newHand,
          faceUp: newFaceUp,
          faceDown: newFaceDown,
        ),
      ),
    );

    // Refill the hand to three immediately after playing (when the stock
    // allows it), so a player who plays a 2 or 10 starts their extra turn
    // with a full hand rather than drawing only after their next play.
    nextState = _drawToThree(nextState, state.currentPlayerIndex);

    if (shouldBurn) {
      nextState = nextState.copyWith(
        burnedPile: List<CardModel>.from(nextState.burnedPile)
          ..addAll(nextState.playPile),
        playPile: <CardModel>[],
      );
      // Burn grants another turn; the player keeps the same index.
      if (_hasPlayerWon(nextState.players[state.currentPlayerIndex])) {
        return nextState.copyWith(
          winnerId: nextState.players[state.currentPlayerIndex].id,
          phase: GamePhase.gameOver,
        );
      }

      return nextState; // Same player index
    }

    // Playing a 2 grants another turn (the pile is not burned).
    if (cards.first.rank == Rank.two) {
      if (_hasPlayerWon(nextState.players[state.currentPlayerIndex])) {
        return nextState.copyWith(
          winnerId: nextState.players[state.currentPlayerIndex].id,
          phase: GamePhase.gameOver,
        );
      }
      return nextState; // Same player index
    }

    // Normal turn transition.
    if (_hasPlayerWon(nextState.players[state.currentPlayerIndex])) {
      return nextState.copyWith(
        winnerId: nextState.players[state.currentPlayerIndex].id,
        phase: GamePhase.gameOver,
      );
    }

    // It was not a burn or a 2: next player's turn
    return nextState.copyWith(
      currentPlayerIndex: (state.currentPlayerIndex + 1) % state.players.length,
    );
  }

  static GameState pickUpPile(GameState state) {
    final PlayerModel currentPlayer = state.currentPlayer;
    final List<CardModel> newHand = List<CardModel>.from(currentPlayer.hand)
      ..addAll(state.playPile);

    final GameState nextState = state.copyWith(
      playPile: <CardModel>[],
      players: _updatePlayerInList(
        state.players,
        state.currentPlayerIndex,
        currentPlayer.copyWith(hand: newHand),
      ),
      currentPlayerIndex: (state.currentPlayerIndex + 1) % state.players.length,
    );

    return nextState;
  }

  /// Endgame action: with an empty hand and an empty stock, the player takes
  /// one of their face-up cards into their hand to play it from there. The
  /// turn does not change — the player still has to play the card afterwards.
  static GameState pickUpFaceUpCard(GameState state, CardModel card) {
    final PlayerModel currentPlayer = state.currentPlayer;
    if (!currentPlayer.faceUp.contains(card)) {
      return state;
    }
    if (currentPlayer.hand.isNotEmpty || state.stock.isNotEmpty) {
      return state;
    }

    final List<CardModel> newHand = List<CardModel>.from(currentPlayer.hand)
      ..add(card);
    final List<CardModel> newFaceUp = List<CardModel>.from(currentPlayer.faceUp)
      ..remove(card);

    return state.copyWith(
      players: _updatePlayerInList(
        state.players,
        state.currentPlayerIndex,
        currentPlayer.copyWith(hand: newHand, faceUp: newFaceUp),
      ),
    );
  }

  static GameState swapCards(
    GameState state,
    int playerIndex,
    CardModel handCard,
    CardModel faceUpCard,
  ) {
    if (state.phase != GamePhase.rearrangement) {
      return state;
    }

    final PlayerModel player = state.players[playerIndex];
    final List<CardModel> newHand = List<CardModel>.from(player.hand);
    final List<CardModel> newFaceUp = List<CardModel>.from(player.faceUp);

    if (newHand.contains(handCard) && newFaceUp.contains(faceUpCard)) {
      newHand.remove(handCard);
      newFaceUp.remove(faceUpCard);
      newHand.add(faceUpCard);
      newFaceUp.add(handCard);
    }

    return state.copyWith(
      players: _updatePlayerInList(
        state.players,
        playerIndex,
        player.copyWith(hand: newHand, faceUp: newFaceUp),
      ),
    );
  }

  static GameState setPlayerReady(GameState state, int playerIndex) {
    final List<PlayerModel> players = _updatePlayerInList(
      state.players,
      playerIndex,
      state.players[playerIndex].copyWith(isReady: true),
    );

    final bool allReady = players.every(
      (PlayerModel p) => p.isReady || p.isBot,
    );

    return state.copyWith(
      players: players,
      phase: allReady ? GamePhase.playing : state.phase,
    );
  }

  static GameState _drawToThree(GameState state, int playerIndex) {
    final PlayerModel player = state.players[playerIndex];
    final List<CardModel> currentHand = List<CardModel>.from(player.hand);
    final List<CardModel> currentStock = List<CardModel>.from(state.stock);

    while (currentHand.length < 3 && currentStock.isNotEmpty) {
      currentHand.add(currentStock.removeAt(0));
    }

    return state.copyWith(
      stock: currentStock,
      players: _updatePlayerInList(
        state.players,
        playerIndex,
        player.copyWith(hand: currentHand),
      ),
    );
  }

  static List<PlayerModel> _updatePlayerInList(
    List<PlayerModel> players,
    int index,
    PlayerModel newPlayer,
  ) {
    final List<PlayerModel> newList = List<PlayerModel>.from(players);
    newList[index] = newPlayer;
    return newList;
  }

  static bool _hasPlayerWon(PlayerModel player) {
    return player.hand.isEmpty &&
        player.faceUp.isEmpty &&
        player.faceDown.isEmpty;
  }

  // Specifically for face-down play
  static GameState playFaceDownCard(GameState state, CardModel card) {
    if (!state.currentPlayer.faceDown.contains(card)) {
      throw Exception("Card not in face down pile");
    }

    if (canPlayCards(<CardModel>[card], state.playPile)) {
      // We need to ensure playCards knows this was a faceDown card to
      // remove it correctly. Actually playCards already handles removal
      // from hand/faceUp/faceDown.
      return playCards(state, <CardModel>[card]);
    } else {
      // Pick up pile AND the flipped card
      final PlayerModel currentPlayer = state.currentPlayer;
      final List<CardModel> newHand = List<CardModel>.from(currentPlayer.hand)
        ..addAll(state.playPile)
        ..add(card);
      final List<CardModel> newFaceDown = List<CardModel>.from(
        currentPlayer.faceDown,
      )..remove(card);

      return state.copyWith(
        playPile: <CardModel>[],
        players: _updatePlayerInList(
          state.players,
          state.currentPlayerIndex,
          currentPlayer.copyWith(hand: newHand, faceDown: newFaceDown),
        ),
        currentPlayerIndex:
            (state.currentPlayerIndex + 1) % state.players.length,
      );
    }
  }

  /// Whether the current player can make a valid move with the card group
  /// they are currently allowed to play from (hand, or face-up once the hand
  /// is empty). When only face-down cards remain, a blind flip is always a
  /// move, so they are never considered stuck.
  static bool currentPlayerHasMove(GameState state) {
    final PlayerModel p = state.currentPlayer;
    if (p.hand.isNotEmpty) {
      return p.hand.any(
        (CardModel c) => canPlayCards(<CardModel>[c], state.playPile),
      );
    }
    if (p.faceUp.isNotEmpty) {
      return p.faceUp.any(
        (CardModel c) => canPlayCards(<CardModel>[c], state.playPile),
      );
    }
    return p.faceDown.isNotEmpty;
  }

  /// Take the top card of the stock as a "chance" card. If it can be played it
  /// goes straight onto the play pile (turn handled by [playCards]); otherwise
  /// the player picks up the play pile plus the chance card and the turn ends.
  static GameState playChanceCard(GameState state) {
    if (state.stock.isEmpty) {
      return state;
    }

    final CardModel chanceCard = state.stock.first;
    final List<CardModel> newStock = List<CardModel>.from(state.stock)
      ..removeAt(0);

    if (canPlayCards(<CardModel>[chanceCard], state.playPile)) {
      // Remove from stock first so playCards' draw step sees the reduced stock.
      return playCards(state.copyWith(stock: newStock), <CardModel>[
        chanceCard,
      ]);
    }

    // Not playable: pick up the play pile and the chance card; turn ends.
    final PlayerModel currentPlayer = state.currentPlayer;
    final List<CardModel> newHand = List<CardModel>.from(currentPlayer.hand)
      ..addAll(state.playPile)
      ..add(chanceCard);

    return state.copyWith(
      stock: newStock,
      playPile: <CardModel>[],
      players: _updatePlayerInList(
        state.players,
        state.currentPlayerIndex,
        currentPlayer.copyWith(hand: newHand),
      ),
      currentPlayerIndex: (state.currentPlayerIndex + 1) % state.players.length,
    );
  }
}

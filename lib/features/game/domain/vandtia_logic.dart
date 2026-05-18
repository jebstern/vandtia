import 'card_models.dart';
import 'game_state.dart';
import 'dart:math';

class VandtiaLogic {
  static List<CardModel> createDeck() {
    final deck = <CardModel>[];
    for (final suit in Suit.values) {
      for (final rank in Rank.values) {
        deck.add(CardModel(suit: suit, rank: rank));
      }
    }
    return deck..shuffle();
  }

  static GameState initialState(List<String> playerNames, {List<bool>? isBot}) {
    final deck = createDeck();
    final players = <PlayerModel>[];
    int deckIndex = 0;

    for (int i = 0; i < playerNames.length; i++) {
      final faceDown = deck.sublist(deckIndex, deckIndex + 3);
      deckIndex += 3;
      final faceUp = deck.sublist(deckIndex, deckIndex + 3);
      deckIndex += 3;
      final hand = deck.sublist(deckIndex, deckIndex + 3);
      deckIndex += 3;

      players.add(PlayerModel(
        id: 'player_$i',
        name: playerNames[i],
        hand: hand,
        faceUp: faceUp,
        faceDown: faceDown,
        isBot: isBot?[i] ?? false,
      ));
    }

    final dealerIndex = Random().nextInt(players.length);
    final currentPlayerIndex = (dealerIndex + 1) % players.length;

    return GameState(
      players: players,
      currentPlayerIndex: currentPlayerIndex,
      stock: deck.sublist(deckIndex),
      playPile: [],
      burnedPile: [],
      phase: GamePhase.rearrangement,
      dealerIndex: dealerIndex,
    );
  }

  static bool canPlayCards(List<CardModel> cards, List<CardModel> playPile) {
    if (cards.isEmpty) return false;
    final rank = cards.first.rank;
    // All cards in a play must have the same rank
    if (!cards.every((c) => c.rank == rank)) return false;

    if (playPile.isEmpty) return true;

    if (rank == Rank.two || rank == Rank.ten) return true;

    final topRank = playPile.last.rank;
    return rank.value >= topRank.value;
  }

  static GameState playCards(GameState state, List<CardModel> cards) {
    if (!canPlayCards(cards, state.playPile)) {
      throw Exception('Invalid move');
    }

    final currentPlayer = state.currentPlayer;
    final newHand = List<CardModel>.from(currentPlayer.hand);
    final newFaceUp = List<CardModel>.from(currentPlayer.faceUp);
    final newFaceDown = List<CardModel>.from(currentPlayer.faceDown);

    // Identify where cards are played from
    bool playedFromFaceDown = false;
    for (final card in cards) {
      if (newHand.contains(card)) {
        newHand.remove(card);
      } else if (newFaceUp.contains(card)) {
        newFaceUp.remove(card);
      } else if (newFaceDown.contains(card)) {
        newFaceDown.remove(card);
        playedFromFaceDown = true;
      }
    }

    final newPlayPile = List<CardModel>.from(state.playPile)..addAll(cards);

    // Check for burn (10 or four-of-a-kind)
    bool shouldBurn = false;
    if (cards.any((c) => c.rank == Rank.ten)) {
      shouldBurn = true;
    } else if (newPlayPile.length >= 4) {
      final lastFour = newPlayPile.sublist(newPlayPile.length - 4);
      if (lastFour.every((c) => c.rank == lastFour.first.rank)) {
        shouldBurn = true;
      }
    }

    GameState nextState = state.copyWith(
      playPile: newPlayPile,
      players: _updatePlayerInList(state.players, state.currentPlayerIndex,
        currentPlayer.copyWith(hand: newHand, faceUp: newFaceUp, faceDown: newFaceDown)),
    );

    if (shouldBurn) {
      nextState = nextState.copyWith(
        burnedPile: List<CardModel>.from(nextState.burnedPile)..addAll(nextState.playPile),
        playPile: [],
      );
      // Drawing happens after the sequence, but burn gives another turn.
      // Rules: "Drawing happens after the entire sequence of a player's turn"
      // Wait, rules also say "After playing, if a player has < 3 cards in hand, they draw from stock until they have 3 or stock is empty."
      // If they get another turn, do they draw NOW or after the extra turn?
      // "after" - according to our previous Q&A.

      // Check for winner before next turn
      if (_hasPlayerWon(nextState.players[state.currentPlayerIndex])) {
        return nextState.copyWith(
          winnerId: nextState.players[state.currentPlayerIndex].id,
          phase: GamePhase.gameOver,
        );
      }

      return nextState; // Same player index
    }

    // Normal turn transition
    // Drawing cards
    nextState = _drawToThree(nextState, state.currentPlayerIndex);

    // Check winner
    if (_hasPlayerWon(nextState.players[state.currentPlayerIndex])) {
        return nextState.copyWith(
          winnerId: nextState.players[state.currentPlayerIndex].id,
          phase: GamePhase.gameOver,
        );
    }

    // Move to next player unless it was a 10/burn
    // Wait, the special cards 2 and 10.
    // 10: burn and another turn. Handled.
    // 2: next player can play anything.
    // Logic for 2 is mostly in canPlayCards.

    // If it was NOT a burn, next player's turn
    return nextState.copyWith(
      currentPlayerIndex: (state.currentPlayerIndex + 1) % state.players.length,
    );
  }

  static GameState pickUpPile(GameState state) {
    final currentPlayer = state.currentPlayer;
    final newHand = List<CardModel>.from(currentPlayer.hand)..addAll(state.playPile);

    final nextState = state.copyWith(
      playPile: [],
      players: _updatePlayerInList(state.players, state.currentPlayerIndex,
        currentPlayer.copyWith(hand: newHand)),
      currentPlayerIndex: (state.currentPlayerIndex + 1) % state.players.length,
    );

    return nextState;
  }

  static GameState swapCards(GameState state, int playerIndex, CardModel handCard, CardModel faceUpCard) {
    if (state.phase != GamePhase.rearrangement) return state;

    final player = state.players[playerIndex];
    final newHand = List<CardModel>.from(player.hand);
    final newFaceUp = List<CardModel>.from(player.faceUp);

    if (newHand.contains(handCard) && newFaceUp.contains(faceUpCard)) {
      newHand.remove(handCard);
      newFaceUp.remove(faceUpCard);
      newHand.add(faceUpCard);
      newFaceUp.add(handCard);
    }

    return state.copyWith(
      players: _updatePlayerInList(state.players, playerIndex,
        player.copyWith(hand: newHand, faceUp: newFaceUp)),
    );
  }

  static GameState setPlayerReady(GameState state, int playerIndex) {
    final players = _updatePlayerInList(state.players, playerIndex,
      state.players[playerIndex].copyWith(isReady: true));

    bool allReady = players.every((p) => p.isReady || p.isBot);

    return state.copyWith(
      players: players,
      phase: allReady ? GamePhase.playing : state.phase,
    );
  }

  static GameState _drawToThree(GameState state, int playerIndex) {
    final player = state.players[playerIndex];
    var currentHand = List<CardModel>.from(player.hand);
    var currentStock = List<CardModel>.from(state.stock);

    while (currentHand.length < 3 && currentStock.isNotEmpty) {
      currentHand.add(currentStock.removeAt(0));
    }

    return state.copyWith(
      stock: currentStock,
      players: _updatePlayerInList(state.players, playerIndex,
        player.copyWith(hand: currentHand)),
    );
  }

  static List<PlayerModel> _updatePlayerInList(List<PlayerModel> players, int index, PlayerModel newPlayer) {
    final newList = List<PlayerModel>.from(players);
    newList[index] = newPlayer;
    return newList;
  }

  static bool _hasPlayerWon(PlayerModel player) {
    return player.hand.isEmpty && player.faceUp.isEmpty && player.faceDown.isEmpty;
  }

  // Specifically for face-down play
  static GameState playFaceDownCard(GameState state, CardModel card) {
    if (!state.currentPlayer.faceDown.contains(card)) {
        throw Exception('Card not in face down pile');
    }

    if (canPlayCards([card], state.playPile)) {
        return playCards(state, [card]);
    } else {
        // Pick up pile AND the flipped card
        final currentPlayer = state.currentPlayer;
        final newHand = List<CardModel>.from(currentPlayer.hand)
            ..addAll(state.playPile)
            ..add(card);
        final newFaceDown = List<CardModel>.from(currentPlayer.faceDown)..remove(card);

        return state.copyWith(
            playPile: [],
            players: _updatePlayerInList(state.players, state.currentPlayerIndex,
                currentPlayer.copyWith(hand: newHand, faceDown: newFaceDown)),
            currentPlayerIndex: (state.currentPlayerIndex + 1) % state.players.length,
        );
    }
  }
}

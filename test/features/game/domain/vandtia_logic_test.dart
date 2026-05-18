import 'package:flutter_test/flutter_test.dart';
import 'package:vandtia/features/game/domain/card_models.dart';
import 'package:vandtia/features/game/domain/game_state.dart';
import 'package:vandtia/features/game/domain/vandtia_logic.dart';

void main() {
  group('VandtiaLogic', () {
    test('Initial state has correct card counts', () {
      final state = VandtiaLogic.initialState(['Player 1', 'Player 2']);
      expect(state.players.length, 2);
      for (final player in state.players) {
        expect(player.hand.length, 3);
        expect(player.faceUp.length, 3);
        expect(player.faceDown.length, 3);
      }
      expect(state.stock.length, 52 - (2 * 9));
      expect(state.phase, GamePhase.rearrangement);
    });

    test('canPlayCards validation', () {
      final lowCard = const CardModel(suit: Suit.hearts, rank: Rank.three);
      final highCard = const CardModel(suit: Suit.hearts, rank: Rank.eight);
      final ten = const CardModel(suit: Suit.spades, rank: Rank.ten);
      final two = const CardModel(suit: Suit.diamonds, rank: Rank.two);

      expect(VandtiaLogic.canPlayCards([lowCard], []), true);
      expect(VandtiaLogic.canPlayCards([highCard], [lowCard]), true);
      expect(VandtiaLogic.canPlayCards([lowCard], [highCard]), false);
      expect(VandtiaLogic.canPlayCards([ten], [highCard]), true);
      expect(VandtiaLogic.canPlayCards([two], [highCard]), true);
      expect(VandtiaLogic.canPlayCards([lowCard], [two]), true); // Anything on 2
    });

    test('10 burns the pile and gives another turn', () {
      var state = VandtiaLogic.initialState(['P1', 'P2']);
      state = state.copyWith(
        phase: GamePhase.playing,
        currentPlayerIndex: 0,
        playPile: [const CardModel(suit: Suit.hearts, rank: Rank.five)],
        players: [
          state.players[0].copyWith(hand: [const CardModel(suit: Suit.spades, rank: Rank.ten)]),
          state.players[1],
        ],
      );

      final newState = VandtiaLogic.playCards(state, [state.players[0].hand.first]);

      expect(newState.playPile.isEmpty, true);
      expect(newState.burnedPile.length, 2);
      expect(newState.currentPlayerIndex, 0); // Still P1's turn
    });

    test('Four of a kind burns the pile', () {
      var state = VandtiaLogic.initialState(['P1', 'P2']);
      final sevens = [
        const CardModel(suit: Suit.hearts, rank: Rank.seven),
        const CardModel(suit: Suit.diamonds, rank: Rank.seven),
        const CardModel(suit: Suit.clubs, rank: Rank.seven),
        const CardModel(suit: Suit.spades, rank: Rank.seven),
      ];

      state = state.copyWith(
        phase: GamePhase.playing,
        currentPlayerIndex: 0,
        playPile: [],
        players: [
          state.players[0].copyWith(hand: sevens),
          state.players[1],
        ],
      );

      final newState = VandtiaLogic.playCards(state, sevens);

      expect(newState.playPile.isEmpty, true);
      expect(newState.currentPlayerIndex, 0);
    });

    test('Drawing back to 3 cards after playing', () {
      var state = VandtiaLogic.initialState(['P1', 'P2']);
      state = state.copyWith(
        phase: GamePhase.playing,
        currentPlayerIndex: 0,
        players: [
          state.players[0].copyWith(hand: [
            const CardModel(suit: Suit.hearts, rank: Rank.five),
            const CardModel(suit: Suit.diamonds, rank: Rank.ace),
          ]),
          state.players[1],
        ],
      );

      final newState = VandtiaLogic.playCards(state, [state.players[0].hand.first]);

      expect(newState.players[0].hand.length, 3); // Drew 2 cards to replace the one played
      expect(newState.currentPlayerIndex, 1);
    });

    test('Picking up the pile', () {
       var state = VandtiaLogic.initialState(['P1', 'P2']);
       final pile = [const CardModel(suit: Suit.hearts, rank: Rank.five)];
       state = state.copyWith(
         phase: GamePhase.playing,
         currentPlayerIndex: 0,
         playPile: pile,
       );

       final newState = VandtiaLogic.pickUpPile(state);

       expect(newState.players[0].hand.contains(pile.first), true);
       expect(newState.playPile.isEmpty, true);
       expect(newState.currentPlayerIndex, 1);
    });
  });
}

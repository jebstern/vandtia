import "package:flutter_test/flutter_test.dart";
import "package:vandtia/features/game/domain/card_models.dart";
import "package:vandtia/features/game/domain/game_state.dart";
import "package:vandtia/features/game/domain/vandtia_logic.dart";

void main() {
  group("VandtiaLogic", () {
    test("Initial state has correct card counts", () {
      final GameState state = VandtiaLogic.initialState(<String>[
        "Player 1",
        "Player 2",
      ]);
      expect(state.players.length, 2);
      for (final PlayerModel player in state.players) {
        expect(player.hand.length, 3);
        expect(player.faceUp.length, 3);
        expect(player.faceDown.length, 3);
      }
      expect(state.stock.length, 52 - (2 * 9));
      expect(state.phase, GamePhase.rearrangement);
    });

    test("canPlayCards validation", () {
      const CardModel lowCard = CardModel(suit: Suit.hearts, rank: Rank.three);
      const CardModel highCard = CardModel(suit: Suit.hearts, rank: Rank.eight);
      const CardModel ten = CardModel(suit: Suit.spades, rank: Rank.ten);
      const CardModel two = CardModel(suit: Suit.diamonds, rank: Rank.two);

      expect(
        VandtiaLogic.canPlayCards(<CardModel>[lowCard], <CardModel>[]),
        true,
      );
      expect(
        VandtiaLogic.canPlayCards(<CardModel>[highCard], <CardModel>[lowCard]),
        true,
      );
      expect(
        VandtiaLogic.canPlayCards(<CardModel>[lowCard], <CardModel>[highCard]),
        false,
      );
      expect(
        VandtiaLogic.canPlayCards(<CardModel>[ten], <CardModel>[highCard]),
        true,
      );
      expect(
        VandtiaLogic.canPlayCards(<CardModel>[two], <CardModel>[highCard]),
        true,
      );
      expect(
        VandtiaLogic.canPlayCards(<CardModel>[lowCard], <CardModel>[two]),
        true,
      ); // Anything on 2
    });

    test("10 burns the pile and gives another turn", () {
      GameState state = VandtiaLogic.initialState(<String>["P1", "P2"]);
      state = state.copyWith(
        phase: GamePhase.playing,
        currentPlayerIndex: 0,
        playPile: <CardModel>[
          const CardModel(suit: Suit.hearts, rank: Rank.five),
        ],
        players: <PlayerModel>[
          state.players[0].copyWith(
            hand: <CardModel>[
              const CardModel(suit: Suit.spades, rank: Rank.ten),
            ],
          ),
          state.players[1],
        ],
      );

      final GameState newState = VandtiaLogic.playCards(state, <CardModel>[
        state.players[0].hand.first,
      ]);

      expect(newState.playPile.isEmpty, true);
      expect(newState.burnedPile.length, 2);
      expect(newState.currentPlayerIndex, 0); // Still P1's turn
    });

    test("Four of a kind burns the pile", () {
      GameState state = VandtiaLogic.initialState(<String>["P1", "P2"]);
      final List<CardModel> sevens = <CardModel>[
        const CardModel(suit: Suit.hearts, rank: Rank.seven),
        const CardModel(suit: Suit.diamonds, rank: Rank.seven),
        const CardModel(suit: Suit.clubs, rank: Rank.seven),
        const CardModel(suit: Suit.spades, rank: Rank.seven),
      ];

      state = state.copyWith(
        phase: GamePhase.playing,
        currentPlayerIndex: 0,
        playPile: <CardModel>[],
        players: <PlayerModel>[
          state.players[0].copyWith(hand: sevens),
          state.players[1],
        ],
      );

      final GameState newState = VandtiaLogic.playCards(state, sevens);

      expect(newState.playPile.isEmpty, true);
      expect(newState.currentPlayerIndex, 0);
    });

    test("Drawing back to 3 cards after playing", () {
      GameState state = VandtiaLogic.initialState(<String>["P1", "P2"]);
      state = state.copyWith(
        phase: GamePhase.playing,
        currentPlayerIndex: 0,
        players: <PlayerModel>[
          state.players[0].copyWith(
            hand: <CardModel>[
              const CardModel(suit: Suit.hearts, rank: Rank.five),
              const CardModel(suit: Suit.diamonds, rank: Rank.ace),
            ],
          ),
          state.players[1],
        ],
      );

      final GameState newState = VandtiaLogic.playCards(state, <CardModel>[
        state.players[0].hand.first,
      ]);

      expect(
        newState.players[0].hand.length,
        3,
      ); // Drew 2 cards to replace the one played
      expect(newState.currentPlayerIndex, 1);
    });

    test("Picking up the pile", () {
      GameState state = VandtiaLogic.initialState(<String>["P1", "P2"]);
      final List<CardModel> pile = <CardModel>[
        const CardModel(suit: Suit.hearts, rank: Rank.five),
      ];
      state = state.copyWith(
        phase: GamePhase.playing,
        currentPlayerIndex: 0,
        playPile: pile,
      );

      final GameState newState = VandtiaLogic.pickUpPile(state);

      expect(newState.players[0].hand.contains(pile.first), true);
      expect(newState.playPile.isEmpty, true);
      expect(newState.currentPlayerIndex, 1);
    });
  });
}

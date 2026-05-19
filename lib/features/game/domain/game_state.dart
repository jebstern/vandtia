import "card_models.dart";

enum GamePhase { setup, rearrangement, playing, gameOver }

class PlayerModel {
  const PlayerModel({
    required this.id,
    required this.name,
    required this.hand,
    required this.faceUp,
    required this.faceDown,
    this.isBot = false,
    this.isReady = false,
  });
  final String id;
  final String name;
  final List<CardModel> hand;
  final List<CardModel> faceUp;
  final List<CardModel> faceDown;
  final bool isBot;
  final bool isReady;

  PlayerModel copyWith({
    List<CardModel>? hand,
    List<CardModel>? faceUp,
    List<CardModel>? faceDown,
    bool? isReady,
  }) {
    return PlayerModel(
      id: id,
      name: name,
      hand: hand ?? this.hand,
      faceUp: faceUp ?? this.faceUp,
      faceDown: faceDown ?? this.faceDown,
      isBot: isBot,
      isReady: isReady ?? this.isReady,
    );
  }
}

class GameState {
  const GameState({
    required this.players,
    required this.currentPlayerIndex,
    required this.stock,
    required this.playPile,
    required this.burnedPile,
    required this.phase,
    required this.dealerIndex,
    this.winnerId,
  });
  final List<PlayerModel> players;
  final int currentPlayerIndex;
  final List<CardModel> stock;
  final List<CardModel> playPile;
  final List<CardModel> burnedPile;
  final GamePhase phase;
  final int dealerIndex;
  final String? winnerId;

  PlayerModel get currentPlayer => players[currentPlayerIndex];

  GameState copyWith({
    List<PlayerModel>? players,
    int? currentPlayerIndex,
    List<CardModel>? stock,
    List<CardModel>? playPile,
    List<CardModel>? burnedPile,
    GamePhase? phase,
    int? dealerIndex,
    String? winnerId,
  }) {
    return GameState(
      players: players ?? this.players,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      stock: stock ?? this.stock,
      playPile: playPile ?? this.playPile,
      burnedPile: burnedPile ?? this.burnedPile,
      phase: phase ?? this.phase,
      dealerIndex: dealerIndex ?? this.dealerIndex,
      winnerId: winnerId ?? this.winnerId,
    );
  }
}

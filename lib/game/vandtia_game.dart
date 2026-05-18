import 'package:flame/game.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/game/providers/game_provider.dart';
import '../features/game/domain/game_state.dart';
import 'components/card_component.dart';
import '../features/game/domain/card_models.dart';
import '../features/game/domain/vandtia_logic.dart';
import 'dart:async';

class VandtiaGame extends FlameGame {
  final WidgetRef ref;
  late GameState _lastState;

  final Map<CardModel, CardComponent> _cardMap = {};

  VandtiaGame(this.ref);

  @override
  Future<void> onLoad() async {
    _lastState = ref.read(gameStateProvider);
    _syncWithState(_lastState);

    // Listen to state changes
    ref.listenManual(gameStateProvider, (previous, next) {
      _syncWithState(next);
    });
  }

  void _syncWithState(GameState state) {
    // Basic sync: remove all and re-add (for MVP, I will optimize with animations later)
    // Actually, let's keep track of cards to animate transitions
    _updateCards(state);
    _lastState = state;
  }

  void _updateCards(GameState state) {
    // Current players
    final user = state.players[0]; // Human
    final bot = state.players[1];  // Bot

    // Layout constants
    final cardSize = Vector2(60, 90);
    final screenWidth = size.x;
    final screenHeight = size.y;

    // 1. Position Stock Pile
    _updatePileCards(state.stock, Vector2(50, screenHeight / 2 - 45), false, false);

    // 2. Position Play Pile
    _updatePileCards(state.playPile, Vector2(screenWidth / 2 - 30, screenHeight / 2 - 45), true, false);

    // 2b. Position Burned Pile Indicator
    _updatePileCards(state.burnedPile, Vector2(screenWidth - 110, screenHeight / 2 - 45), true, false);

    // 3. Position User Hand
    _updateHandCards(user.hand, Vector2(screenWidth / 2, screenHeight - 80), true, true);

    // 4. Position User Table
    _updateTableCards(user.faceUp, user.faceDown, Vector2(screenWidth / 2, screenHeight - 200), true);

    // 5. Position Bot Hand
    _updateHandCards(bot.hand, Vector2(screenWidth / 2, 80), false, false);

    // 6. Position Bot Table
    _updateTableCards(bot.faceUp, bot.faceDown, Vector2(screenWidth / 2, 200), false);
  }

  void _updatePileCards(List<CardModel> cards, Vector2 pos, bool faceUp, bool draggable) {
    for (int i = 0; i < cards.length; i++) {
        final card = cards[i];
        final comp = _getOrCreateCard(card);
        final targetPos = pos + Vector2(i * 0.5, -i * 0.5);

        if (comp.isFaceUp != faceUp) comp.flip(faceUp: faceUp);
        comp.isDraggable = draggable;
        comp.moveTo(targetPos);
        if (comp.parent == null) {
            comp.position = Vector2(size.x / 2, size.y / 2); // Start from middle for deal effect
            add(comp);
        }
    }
  }

  void _updateHandCards(List<CardModel> cards, Vector2 centerPos, bool faceUp, bool draggable) {
    final spacing = 40.0;
    final totalWidth = (cards.length - 1) * spacing;
    final startX = centerPos.x - totalWidth / 2;

    for (int i = 0; i < cards.length; i++) {
        final card = cards[i];
        final comp = _getOrCreateCard(card);
        final targetPos = Vector2(startX + i * spacing - 30, centerPos.y - 45);

        if (comp.isFaceUp != faceUp) comp.flip(faceUp: faceUp);

        bool canDrag = draggable;
        if (_lastState.phase == GamePhase.rearrangement) {
            canDrag = !(_lastState.players[0].isReady);
        } else if (_lastState.phase == GamePhase.playing) {
            canDrag = _lastState.currentPlayerIndex == 0;
        } else {
            canDrag = false;
        }

        comp.isDraggable = canDrag;
        comp.moveTo(targetPos);
        if (comp.parent == null) {
            comp.position = Vector2(size.x / 2, size.y / 2);
            add(comp);
        }
    }
  }

  void _updateTableCards(List<CardModel> faceUp, List<CardModel> faceDown, Vector2 centerPos, bool isUser) {
    final spacing = 70.0;
    for (int i = 0; i < 3; i++) {
        // Face down
        if (faceDown.length > i) {
            final card = faceDown[i];
            final comp = _getOrCreateCard(card);
            final targetPos = Vector2(centerPos.x + (i - 1) * spacing - 30, centerPos.y - 45);
            if (comp.isFaceUp) comp.flip(faceUp: false);
            comp.isDraggable = false;
            comp.moveTo(targetPos);
            if (comp.parent == null) {
                comp.position = Vector2(size.x / 2, size.y / 2);
                add(comp);
            }
        }

        // Face up on top
        if (faceUp.length > i) {
            final card = faceUp[i];
            final comp = _getOrCreateCard(card);
            final targetPos = Vector2(centerPos.x + (i - 1) * spacing - 30, centerPos.y - 45);

            bool shouldShow = true;
            if (_lastState.phase == GamePhase.rearrangement && !isUser) {
                shouldShow = false;
            }

            if (comp.isFaceUp != shouldShow) comp.flip(faceUp: shouldShow);

            bool canDrag = isUser;
            if (_lastState.phase == GamePhase.rearrangement) {
                canDrag = !(_lastState.players[0].isReady);
            } else if (_lastState.phase == GamePhase.playing) {
                canDrag = _lastState.currentPlayerIndex == 0 && _lastState.players[0].hand.isEmpty;
            } else {
                canDrag = false;
            }

            comp.isDraggable = canDrag;
            comp.moveTo(targetPos);
            if (comp.parent == null) {
                comp.position = Vector2(size.x / 2, size.y / 2);
                add(comp);
            }
        }
    }
  }

  CardComponent _getOrCreateCard(CardModel model) {
    if (_cardMap.containsKey(model)) {
        return _cardMap[model]!;
    }
    final comp = CardComponent(
        model: model,
        onDraggedToPile: _onCardDropped,
        onTap: _onCardTapped,
    );
    _cardMap[model] = comp;
    return comp;
  }

  final Set<CardModel> _selectedCards = {};

  void _onCardDropped(CardComponent card) {
    if (_lastState.phase == GamePhase.playing) {
      final playPilePos = Vector2(size.x / 2 - 30, size.y / 2 - 45);
      if (card.position.distanceTo(playPilePos) < 100) {
        // If we have multiple selected, play all. Otherwise play the one dropped.
        final cardsToPlay = _selectedCards.isNotEmpty
            ? _selectedCards.toList()
            : [card.model];

        if (VandtiaLogic.canPlayCards(cardsToPlay, _lastState.playPile)) {
          ref.read(gameStateProvider.notifier).playCards(cardsToPlay);
          _selectedCards.clear();
          for (final c in _cardMap.values) {
              c.isSelected = false;
          }
        } else {
          _updateCards(_lastState);
        }
      } else {
        _updateCards(_lastState);
      }
    } else if (_lastState.phase == GamePhase.rearrangement) {
        // Swap logic: if dropped on a face-up card
        final user = _lastState.players[0];
        for (int i = 0; i < user.faceUp.length; i++) {
             final faceUpCard = user.faceUp[i];
             final comp = _cardMap[faceUpCard];
             if (comp != null && card.position.distanceTo(comp.position) < 50 && card != comp) {
                  if (user.hand.contains(card.model)) {
                      ref.read(gameStateProvider.notifier).swapCards(card.model, faceUpCard);
                      return;
                  }
             }
        }
        _updateCards(_lastState);
    }
  }

  void _onCardTapped(CardComponent card) {
    if (_lastState.phase == GamePhase.playing && _lastState.currentPlayerIndex == 0) {
        // Selection logic for multiple cards
        if (_lastState.currentPlayer.hand.contains(card.model) ||
            (_lastState.currentPlayer.hand.isEmpty && _lastState.currentPlayer.faceUp.contains(card.model))) {

            if (_selectedCards.contains(card.model)) {
                _selectedCards.remove(card.model);
                card.isSelected = false;
            } else {
                // Can only select same rank
                if (_selectedCards.isEmpty || _selectedCards.first.rank == card.model.rank) {
                    _selectedCards.add(card.model);
                    card.isSelected = true;
                }
            }
            return;
        }

        // Face down play
        if (_lastState.currentPlayer.hand.isEmpty &&
            _lastState.currentPlayer.faceUp.isEmpty &&
            _lastState.currentPlayer.faceDown.contains(card.model)) {

            ref.read(gameStateProvider.notifier).playFaceDownCard(card.model);
        }
    }
  }
}

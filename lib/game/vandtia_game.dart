import "dart:async";

import "package:flame/components.dart";
import "package:flame/game.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../features/game/domain/card_models.dart";
import "../features/game/domain/game_state.dart";
import "../features/game/domain/vandtia_logic.dart";
import "../features/game/providers/game_provider.dart";
import "components/card_component.dart";

class VandtiaGame extends FlameGame<World> {
  VandtiaGame(this.ref);

  // A chance card flips face-up (~0.2s) then stays on the stock for 2 seconds
  // so it can be read, before sliding to its destination.
  static const double _chanceRevealDelay = 2.2;

  final WidgetRef ref;
  late GameState _lastState;

  final Map<CardModel, CardComponent> _cardMap = <CardModel, CardComponent>{};

  // The human's hand card currently "peeked" (popped out so it can be read).
  CardModel? _peekedCard;

  // The chance card detected on the current sync (recomputed every sync from
  // the state diff). Triggers the start of a reveal animation.
  CardModel? _chanceRevealCard;

  // A chance card currently mid reveal-animation. While set, _updateCards
  // leaves this card untouched so the flip/hold/slide is not interrupted.
  CardModel? _revealingCard;

  @override
  Future<void> onLoad() async {
    _lastState = ref.read(gameStateProvider);
    _syncWithState(_lastState);

    // Listen to state changes
    ref.listenManual(gameStateProvider, (GameState? previous, GameState next) {
      _chanceRevealCard = _detectChanceCard(previous, next);
      _syncWithState(next);
    });
  }

  /// Identifies a card just flipped from the stock as a chance card. A chance
  /// card can only be taken when the previous player had no valid move; the
  /// only other option then is picking up the pile, which leaves the stock
  /// untouched. So a stuck player whose stock top vanished took a chance card.
  CardModel? _detectChanceCard(GameState? previous, GameState next) {
    if (previous == null || previous.phase != GamePhase.playing) {
      return null;
    }
    if (previous.stock.isEmpty || VandtiaLogic.currentPlayerHasMove(previous)) {
      return null;
    }
    final CardModel top = previous.stock.first;
    return next.stock.contains(top) ? null : top;
  }

  void _syncWithState(GameState state) {
    // Update _lastState first: _updateCards (and its helpers) read _lastState
    // to decide draggability, so it must reflect the incoming state.
    _lastState = state;
    _updateCards(state);
  }

  void _updateCards(GameState state) {
    // Current players
    final PlayerModel user = state.players[0]; // Human
    final PlayerModel bot = state.players[1]; // Bot

    // Layout constants
    final double screenWidth = size.x;
    final double screenHeight = size.y;

    // 1. Position Stock Pile
    _updatePileCards(
      state.stock,
      Vector2(50, screenHeight / 2 - 45),
      false,
      false,
    );

    // 2. Position Play Pile
    _updatePileCards(
      state.playPile,
      Vector2(screenWidth / 2 - 30, screenHeight / 2 - 45),
      true,
      false,
      peekTop: true,
    );

    // 2b. Position Burned Pile Indicator
    _updatePileCards(
      state.burnedPile,
      Vector2(screenWidth - 110, screenHeight / 2 - 45),
      true,
      false,
    );

    // 3. Position User Hand
    _updateHandCards(
      user.hand,
      Vector2(screenWidth / 2, screenHeight - 70),
      true,
      true,
    );

    // 4. Position User Table
    _updateTableCards(
      user.faceUp,
      user.faceDown,
      Vector2(screenWidth / 2, screenHeight - 200),
      true,
    );

    // 5. Position Bot Hand
    _updateHandCards(bot.hand, Vector2(screenWidth / 2, 70), false, false);

    // 6. Position Bot Table
    _updateTableCards(
      bot.faceUp,
      bot.faceDown,
      Vector2(screenWidth / 2, 200),
      false,
    );
  }

  void _updatePileCards(
    List<CardModel> cards,
    Vector2 pos,
    bool faceUp,
    bool draggable, {
    bool peekTop = false,
  }) {
    for (int i = 0; i < cards.length; i++) {
      final CardModel card = cards[i];
      final CardComponent comp = _getOrCreateCard(card);

      // A chance card mid reveal-animation owns its own flip and position;
      // leave it alone until the animation finishes.
      if (card == _revealingCard) {
        continue;
      }

      final bool isTop = i == cards.length - 1;

      // Stack cards at the base position. For the play pile, slide the top
      // card aside so the previous card's rank stays readable underneath.
      final Vector2 targetPos = (peekTop && isTop && cards.length > 1)
          ? pos + Vector2(32, 0)
          : pos;

      // Render newer cards above older ones so the latest play is on top.
      comp.priority = i;

      // Start the reveal for a freshly taken chance card: it flips face-up,
      // holds, then slides here.
      if (card == _chanceRevealCard &&
          _revealingCard == null &&
          !comp.isFaceUp &&
          faceUp) {
        _beginChanceReveal(comp, card, targetPos);
        continue;
      }

      if (comp.isFaceUp != faceUp) {
        comp.flip(faceUp: faceUp);
      }
      comp
        ..isDraggable = draggable
        ..moveTo(targetPos);
      if (comp.parent == null) {
        comp.position = Vector2(
          size.x / 2,
          size.y / 2,
        ); // Start from middle for deal effect
        unawaited(Future<void>.value(add(comp)));
      }
    }
  }

  void _updateHandCards(
    List<CardModel> cards,
    Vector2 centerPos,
    bool faceUp,
    bool draggable,
  ) {
    if (cards.isEmpty) {
      return;
    }

    const double cardWidth = 70;
    const double gap = 8;

    // Cards sit side by side with a small gap. For large hands (e.g. after
    // picking up the pile) shrink the step so the row stays on screen.
    double spacing = cardWidth + gap;
    final double maxRowWidth = size.x - 20;
    final double fullWidth = (cards.length - 1) * spacing + cardWidth;
    if (cards.length > 1 && fullWidth > maxRowWidth) {
      spacing = (maxRowWidth - cardWidth) / (cards.length - 1);
    }

    final double rowWidth = (cards.length - 1) * spacing + cardWidth;
    final double startX = centerPos.x - rowWidth / 2;

    for (int i = 0; i < cards.length; i++) {
      final CardModel card = cards[i];
      final CardComponent comp = _getOrCreateCard(card);

      // A chance card mid reveal-animation owns its own flip and position;
      // leave it alone until the animation finishes.
      if (card == _revealingCard) {
        continue;
      }

      // A peeked card pops out to the right and jumps to the front so its
      // rank and suit are fully readable. Only move it when it is actually
      // obscured: a card is fully visible if nothing overlaps it (no overlap
      // at all, or it is the rightmost card).
      final bool isObscured = spacing < cardWidth && i < cards.length - 1;
      final bool isPeeked = card == _peekedCard && isObscured;
      final Vector2 targetPos = isPeeked
          ? Vector2(startX + i * spacing + 50, centerPos.y - 60)
          : Vector2(startX + i * spacing, centerPos.y - 45);

      // Layer cards left-to-right so each card's rank corner stays visible.
      comp.priority = isPeeked ? 1000 : i;

      // Start the reveal for a freshly taken chance card landing in the hand.
      if (card == _chanceRevealCard &&
          _revealingCard == null &&
          !comp.isFaceUp &&
          faceUp) {
        _beginChanceReveal(comp, card, targetPos);
        continue;
      }

      if (comp.isFaceUp != faceUp) {
        comp.flip(faceUp: faceUp);
      }

      bool canDrag = draggable;
      if (_lastState.phase == GamePhase.rearrangement) {
        canDrag = !_lastState.players[0].isReady;
      } else if (_lastState.phase == GamePhase.playing) {
        canDrag = _lastState.currentPlayerIndex == 0;
      } else {
        canDrag = false;
      }

      comp
        ..isDraggable = canDrag
        ..moveTo(targetPos);
      if (comp.parent == null) {
        comp.position = Vector2(size.x / 2, size.y / 2);
        unawaited(Future<void>.value(add(comp)));
      }
    }
  }

  /// Starts a chance card's reveal: it flips face-up, holds on the stock for
  /// the reveal delay, then slides to [target]. While the animation runs the
  /// card is marked as [_revealingCard] so syncs leave it untouched; once it
  /// finishes the board is re-synced so the card settles correctly.
  void _beginChanceReveal(CardComponent comp, CardModel card, Vector2 target) {
    _revealingCard = card;
    comp
      ..priority =
          2000 // render above every other card during the reveal
      ..flip(faceUp: true)
      ..moveTo(target, delay: _chanceRevealDelay);

    final int totalMs = ((_chanceRevealDelay + 0.3) * 1000).round();
    unawaited(
      Future<void>.delayed(Duration(milliseconds: totalMs), () {
        if (_revealingCard == card) {
          _revealingCard = null;
          _updateCards(_lastState);
        }
      }),
    );
  }

  void _updateTableCards(
    List<CardModel> faceUp,
    List<CardModel> faceDown,
    Vector2 centerPos,
    bool isUser,
  ) {
    const double spacing = 70;
    for (int i = 0; i < 3; i++) {
      // Face down
      if (faceDown.length > i) {
        final CardModel card = faceDown[i];
        final CardComponent comp = _getOrCreateCard(card);
        final Vector2 targetPos = Vector2(
          centerPos.x + (i - 1) * spacing - 30,
          centerPos.y - 45,
        );
        comp.priority = 0;
        if (comp.isFaceUp) {
          comp.flip(faceUp: false);
        }
        comp
          ..isDraggable = false
          ..moveTo(targetPos);
        if (comp.parent == null) {
          comp.position = Vector2(size.x / 2, size.y / 2);
          unawaited(Future<void>.value(add(comp)));
        }
      }

      // Face up on top
      if (faceUp.length > i) {
        final CardModel card = faceUp[i];
        final CardComponent comp = _getOrCreateCard(card);
        final Vector2 targetPos = Vector2(
          centerPos.x + (i - 1) * spacing - 30,
          centerPos.y - 45,
        );

        // Face-up cards render above their face-down counterpart.
        comp.priority = 1;

        bool shouldShow = true;
        if (_lastState.phase == GamePhase.rearrangement && !isUser) {
          shouldShow = false;
        }

        if (comp.isFaceUp != shouldShow) {
          comp.flip(faceUp: shouldShow);
        }

        // Face-up cards are draggable only during rearrangement (for
        // swapping). In play they are tapped to pick up, never dragged.
        final bool canDrag =
            _lastState.phase == GamePhase.rearrangement &&
            isUser &&
            !_lastState.players[0].isReady;

        comp
          ..isDraggable = canDrag
          ..moveTo(targetPos);
        if (comp.parent == null) {
          comp.position = Vector2(size.x / 2, size.y / 2);
          unawaited(Future<void>.value(add(comp)));
        }
      }
    }
  }

  CardComponent _getOrCreateCard(CardModel model) {
    if (_cardMap.containsKey(model)) {
      return _cardMap[model]!;
    }
    final CardComponent comp = CardComponent(
      model: model,
      onDraggedToPile: _onCardDropped,
      onTap: _onCardTapped,
    );
    _cardMap[model] = comp;
    return comp;
  }

  final Set<CardModel> _selectedCards = <CardModel>{};

  void _onCardDropped(CardComponent card) {
    if (_lastState.phase == GamePhase.playing) {
      final Vector2 playPilePos = Vector2(size.x / 2 - 30, size.y / 2 - 45);
      if (card.position.distanceTo(playPilePos) < 100) {
        // Play the explicitly selected cards, or just the dropped card.
        // The player chooses multiples themselves by tapping to select.
        final List<CardModel> cardsToPlay = _selectedCards.isNotEmpty
            ? _selectedCards.toList()
            : <CardModel>[card.model];

        if (VandtiaLogic.canPlayCards(cardsToPlay, _lastState.playPile)) {
          ref.read(gameStateProvider.notifier).playCards(cardsToPlay);
          _selectedCards.clear();
          _peekedCard = null;
          for (final CardComponent c in _cardMap.values) {
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
      final PlayerModel user = _lastState.players[0];
      final Vector2 cardCenter = card.position + card.size / 2;

      for (int i = 0; i < user.faceUp.length; i++) {
        final CardModel faceUpCard = user.faceUp[i];
        final CardComponent? targetComp = _cardMap[faceUpCard];
        if (targetComp != null && targetComp != card) {
          final Vector2 targetCenter =
              targetComp.position + targetComp.size / 2;
          if (cardCenter.distanceTo(targetCenter) < 60) {
            if (user.hand.contains(card.model)) {
              ref
                  .read(gameStateProvider.notifier)
                  .swapCards(card.model, faceUpCard);
              return;
            } else if (user.faceUp.contains(card.model)) {
              // Allow face-up to hand swap by dropping face-up on a hand card?
              // The logic currently supports swapping any hand card with any
              // face-up card. If we drop a face-up card on any hand card, we
              // can trigger swap.
            }
          }
        }
      }

      // Also allow dropping a face-up card onto the hand area to swap
      if (user.faceUp.contains(card.model)) {
        for (final CardModel handCard in user.hand) {
          final CardComponent? targetComp = _cardMap[handCard];
          if (targetComp != null) {
            final Vector2 targetCenter =
                targetComp.position + targetComp.size / 2;
            if (cardCenter.distanceTo(targetCenter) < 60) {
              ref
                  .read(gameStateProvider.notifier)
                  .swapCards(handCard, card.model);
              return;
            }
          }
        }
      }

      _updateCards(_lastState);
    }
  }

  void _onCardTapped(CardComponent card) {
    // Peek: tapping a card in the human's hand pops it out so the rank and
    // suit can be read, even when the hand is too packed to see them all.
    if (_lastState.players[0].hand.contains(card.model)) {
      _peekedCard = (_peekedCard == card.model) ? null : card.model;
      _updateCards(_lastState);
    }

    if (_lastState.phase == GamePhase.playing &&
        _lastState.currentPlayerIndex == 0) {
      final PlayerModel player = _lastState.currentPlayer;

      // Endgame: with an empty hand and an empty stock, tap a face-up card to
      // take it into the hand and play it from there.
      if (player.hand.isEmpty &&
          _lastState.stock.isEmpty &&
          player.faceUp.contains(card.model)) {
        ref.read(gameStateProvider.notifier).pickUpFaceUpCard(card.model);
        return;
      }

      // Selection logic for multiple hand cards
      if (player.hand.contains(card.model)) {
        if (_selectedCards.contains(card.model)) {
          _selectedCards.remove(card.model);
          card.isSelected = false;
        } else {
          // Can only select same rank
          if (_selectedCards.isEmpty ||
              _selectedCards.first.rank == card.model.rank) {
            _selectedCards.add(card.model);
            card.isSelected = true;
          }
        }
        return;
      }

      // Face down play
      if (player.hand.isEmpty &&
          player.faceUp.isEmpty &&
          player.faceDown.contains(card.model)) {
        ref.read(gameStateProvider.notifier).playFaceDownCard(card.model);
      }
    }
  }
}

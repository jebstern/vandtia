import "dart:async";

import "package:flame/components.dart";
import "package:flame/effects.dart";
import "package:flame/events.dart";
import "package:flutter/material.dart";
import "../../features/game/domain/card_models.dart";

class CardComponent extends PositionComponent with DragCallbacks, TapCallbacks {
  CardComponent({
    required this.model,
    this.isFaceUp = false,
    this.isDraggable = false,
    this.onDraggedToPile,
    this.onTap,
    Vector2? size,
  }) : super(size: size ?? Vector2(70, 100));
  final CardModel model;
  bool isFaceUp;
  bool isDraggable;
  bool isSelected = false;
  final Function(CardComponent)? onDraggedToPile;
  final Function(CardComponent)? onTap;

  @override
  Future<void> onLoad() async {
    await _updateSprite();
  }

  Future<void> _updateSprite() async {
    if (isFaceUp) {
      // For now, draw a simple placeholder card if assets aren't ready
      // I'll implement a fallback renderer
    } else {
      // Back of card
    }
  }

  @override
  void render(Canvas canvas) {
    final Paint paint = Paint()
      ..color = isSelected ? Colors.green.shade100 : Colors.white;
    final Paint borderPaint = Paint()
      ..color = isSelected ? Colors.green : Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 4 : 2;

    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(size.toRect(), const Radius.circular(8)),
        paint,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(size.toRect(), const Radius.circular(8)),
        borderPaint,
      );

    if (isFaceUp) {
      _renderFront(canvas);
    } else {
      _renderBack(canvas);
    }
  }

  void _renderFront(Canvas canvas) {
    final Color color =
        (model.suit == Suit.hearts || model.suit == Suit.diamonds)
        ? Colors.red
        : Colors.black;
    TextPainter(
        text: TextSpan(
          text: "${_rankToString(model.rank)}\n${_suitToChar(model.suit)}",
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout()
      ..paint(canvas, const Offset(8, 8));
  }

  void _renderBack(Canvas canvas) {
    final Paint paint = Paint()..color = Colors.blue.shade800;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        size.toRect().deflate(4),
        const Radius.circular(4),
      ),
      paint,
    );
  }

  void moveTo(
    Vector2 targetPosition, {
    double duration = 0.3,
    double delay = 0,
  }) {
    final MoveToEffect effect = MoveToEffect(
      targetPosition,
      EffectController(
        duration: duration,
        startDelay: delay,
        curve: Curves.easeInOut,
      ),
    );
    unawaited(Future<void>.value(add(effect)));
  }

  void flip({required bool faceUp}) {
    if (isFaceUp == faceUp) {
      return;
    }

    // Simple scale-based flip animation
    final ScaleEffect collapse = ScaleEffect.to(
      Vector2(0, 1),
      EffectController(duration: 0.1, curve: Curves.easeIn),
      onComplete: () {
        isFaceUp = faceUp;
        final ScaleEffect restore = ScaleEffect.to(
          Vector2(1, 1),
          EffectController(duration: 0.1, curve: Curves.easeOut),
        );
        unawaited(Future<void>.value(add(restore)));
      },
    );
    unawaited(Future<void>.value(add(collapse)));
  }

  String _rankToString(Rank rank) => switch (rank) {
    Rank.jack => "J",
    Rank.queen => "Q",
    Rank.king => "K",
    Rank.ace => "A",
    _ => rank.value.toString(),
  };

  String _suitToChar(Suit suit) {
    switch (suit) {
      case Suit.clubs:
        return "♣";
      case Suit.diamonds:
        return "♦";
      case Suit.hearts:
        return "♥";
      case Suit.spades:
        return "♠";
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!isDraggable) {
      return;
    }
    priority = 100; // Bring to front
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!isDraggable) {
      return;
    }
    position += event.localDelta;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (!isDraggable) {
      return;
    }
    // Clear the drag's "bring to front" priority before handing off: the drop
    // handler re-lays out the board and assigns the correct stacking priority,
    // which must not be overwritten afterwards.
    priority = 0;
    onDraggedToPile?.call(this);
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    // Fires only for a real tap. A press that becomes a drag is delivered as
    // onTapCancel instead, so dragging a card never selects/peeks it.
    onTap?.call(this);
  }
}

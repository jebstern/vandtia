import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../../features/game/domain/card_models.dart';

class CardComponent extends PositionComponent with DragCallbacks, TapCallbacks {
  final CardModel model;
  bool isFaceUp;
  bool isDraggable;
  bool isSelected = false;
  final Function(CardComponent)? onDraggedToPile;
  final Function(CardComponent)? onTap;

  CardComponent({
    required this.model,
    this.isFaceUp = false,
    this.isDraggable = false,
    this.onDraggedToPile,
    this.onTap,
    Vector2? size,
  }) : super(size: size ?? Vector2(70, 100));

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
    final paint = Paint()..color = isSelected ? Colors.green.shade100 : Colors.white;
    final borderPaint = Paint()
      ..color = isSelected ? Colors.green : Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 4 : 2;

    canvas.drawRRect(RRect.fromRectAndRadius(size.toRect(), const Radius.circular(8)), paint);
    canvas.drawRRect(RRect.fromRectAndRadius(size.toRect(), const Radius.circular(8)), borderPaint);

    if (isFaceUp) {
      _renderFront(canvas);
    } else {
      _renderBack(canvas);
    }
  }

  void _renderFront(Canvas canvas) {
    final color = (model.suit == Suit.hearts || model.suit == Suit.diamonds) ? Colors.red : Colors.black;
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${_rankToString(model.rank)}\n${_suitToChar(model.suit)}',
        style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(8, 8));
  }

  void _renderBack(Canvas canvas) {
    final paint = Paint()..color = Colors.blue.shade800;
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect().deflate(4), const Radius.circular(4)),
      paint,
    );
  }

  void moveTo(Vector2 targetPosition, {double duration = 0.3}) {
    add(
      MoveToEffect(
        targetPosition,
        EffectController(duration: duration, curve: Curves.easeInOut),
      ),
    );
  }

  void flip({required bool faceUp}) {
    // Simple scale-based flip animation
    add(
      ScaleEffect.to(
        Vector2(0, 1),
        EffectController(duration: 0.1, curve: Curves.easeIn),
        onComplete: () {
          isFaceUp = faceUp;
          add(
            ScaleEffect.to(
              Vector2(1, 1),
              EffectController(duration: 0.1, curve: Curves.easeOut),
            ),
          );
        },
      ),
    );
  }

  String _rankToString(Rank rank) {
    switch (rank) {
      case Rank.jack: return 'J';
      case Rank.queen: return 'Q';
      case Rank.king: return 'K';
      case Rank.ace: return 'A';
      default: return rank.value.toString();
    }
  }

  String _suitToChar(Suit suit) {
    switch (suit) {
      case Suit.clubs: return '♣';
      case Suit.diamonds: return '♦';
      case Suit.hearts: return '♥';
      case Suit.spades: return '♠';
    }
  }

  Vector2? _dragStartPos;
  Vector2? _dragStartParentPos;

  @override
  void onDragStart(DragStartEvent event) {
    if (!isDraggable) return;
    _dragStartPos = event.localPosition;
    _dragStartParentPos = position.clone();
    priority = 100; // Bring to front
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!isDraggable) return;
    position += event.localDelta;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    if (!isDraggable) return;
    if (onDraggedToPile != null) {
      onDraggedToPile!(this);
    }
    priority = 0;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (onTap != null) {
        onTap!(this);
    }
  }
}

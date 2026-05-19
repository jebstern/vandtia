import "package:flutter/material.dart";

enum Suit { clubs, diamonds, hearts, spades }

enum Rank {
  two(2),
  three(3),
  four(4),
  five(5),
  six(6),
  seven(7),
  eight(8),
  nine(9),
  ten(10),
  jack(11),
  queen(12),
  king(13),
  ace(14);

  const Rank(this.value);
  final int value;
}

@immutable
class CardModel {
  const CardModel({required this.suit, required this.rank});
  final Suit suit;
  final Rank rank;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardModel &&
          runtimeType == other.runtimeType &&
          suit == other.suit &&
          rank == other.rank;

  @override
  int get hashCode => suit.hashCode ^ rank.hashCode;

  @override
  String toString() => "$rank of $suit";
}

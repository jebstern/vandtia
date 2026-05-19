# Vändtia

A digital version of the Swedish card game **Vändtia** ("turn ten"), built with
Flutter. The MVP is a single-player game: a human player versus a bot.

Each player holds three hand cards, three face-up cards, and three hidden
face-down cards. Players race to shed all of their cards by playing onto a
shared pile, with special cards (2, 10, and four-of-a-kind) that burn the pile
or grant extra turns.

The full ruleset is in [RULES.md](RULES.md).

## Running the game

```sh
flutter pub get
flutter run
```

Run the tests with:

```sh
flutter test
```

## Tech stack

- **Flutter** (Dart SDK `^3.11.0`)
- **[Flame](https://flame-engine.org/)** — the card board, rendering, and
  drag/tap/animation handling.
- **[Riverpod](https://riverpod.dev/)** — game state management.

## Project layout

- `lib/features/game/domain/` — game models and pure rules logic
  (`vandtia_logic.dart`, `game_state.dart`, `card_models.dart`).
- `lib/features/game/providers/` — the Riverpod `GameNotifier`, including the
  bot's move logic.
- `lib/game/` — the Flame game (`vandtia_game.dart`) and the card component.
- `lib/game_screen.dart` — the screen hosting the game widget and UI overlays.
- `test/` — unit tests for the rules logic.

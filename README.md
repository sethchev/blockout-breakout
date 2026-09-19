# Blockout Breakout

A Breakout-style arcade game for the Omarchy shell. Clear ten increasingly fast levels, chase a high score, crack special ice blocks, and collect missile-launcher power-ups without losing all three lives.

## Gameplay

Each level contains six rows of ten blocks. Clear all 60 blocks to advance automatically; finish level 10 to win. The ball moves 10% faster with each new level, while the score and remaining lives carry forward.

Blocks score according to their row, counted from the bottom:

| Row | Points per block |
| --- | ---------------- |
| 6 (top) | 6 |
| 5 | 5 |
| 4 | 4 |
| 3 | 3 |
| 2 | 2 |
| 1 (bottom) | 1 |

Clearing an entire row awards an additional 10 points. The final score is shown after a win or game over.

Every level also contains one randomly placed ice block. It takes three hits to break and drops a birthday gift. Catch the gift with the paddle to equip a missile launcher on each side, then press `Alt` to fire at the blocks. The launchers are lost when a life is lost.

## Install

Install and enable the plugin directly from GitHub:

```sh
omarchy plugin add https://github.com/sethchev/blockout-breakout.git --enable
```

`omarchy plugin install` is an alias for `omarchy plugin add`, so this works too:

```sh
omarchy plugin install https://github.com/sethchev/blockout-breakout.git --enable
```

Launch or close the game with:

```sh
omarchy-shell shell toggle sethchev.blockout-breakout
```

Update an installed copy with:

```sh
omarchy plugin update sethchev.blockout-breakout
```

## Controls

- `Left` / `A`: move the paddle left
- `Right` / `D`: move the paddle right
- `Space`: launch the ball or pause/resume
- `Alt`: fire the missile launchers after collecting a gift
- `R`: restart from level 1
- `Escape`: close the game

## Requirements

- Omarchy with the Quickshell-based Omarchy shell and plugin CLI

## License

MIT

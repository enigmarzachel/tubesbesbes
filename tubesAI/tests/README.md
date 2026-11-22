# AI smoke tests

Run from the project root with Godot 4.7:

```sh
godot --headless --path . --script res://tests/ai_smoke_tests.gd
```

The script checks weighted pathfinding and unreachable goals, Minimax versus
Alpha-Beta equivalence and node counts, Expectimax legal actions, Local Search
fitness, propositional inference, forward/backward planning, all eight lesson
control layouts, Local Search NPC wiring/chase/battle entry, and CSP
benchmark/spawn integration.

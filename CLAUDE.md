# The Street — Roblox finance career game

Read before changing anything:
- `docs/superpowers/specs/2026-10-15-the-street-design.md`: what the game is, with every design number.
- `docs/contracts.md`: cross-feature interfaces, data schema, file ownership, bake-safe rules. **Stay inside your
  feature's files** (§12). If you need something from another feature, call its documented API. Never edit their
  files. If an API you need is missing, add a clearly-marked TODO note to your final report instead of inventing one.
- `docs/blueprint/`: the owner's original design blueprint.

## Toolchain (all available on PATH)

| Command | What it does |
|---|---|
| `tools/check.sh` | Everything: unit tests, world bake, strict type-check, format check, `.rbxl` build. Must pass before you finish. |
| `tools/check.sh --quick` | Tests + type-check + format only. |
| `lune run tools/test [filter...]` | Lune unit tests (`tests/**/*.spec.luau`), optionally filtered by path substring. |
| `lune run tools/bake [Module...]` | Bake world builders into `build/World.rbxm`; reports part counts, budgets and out-of-zone parts. |
| `stylua src tools tests` | Format (tabs, 120 cols). Run before finishing. |
| `rojo build default.project.json -o build/TheStreet.rbxl` | Build the place file. |

There is **no Roblox engine** here. Automated checks are all we have, so lean on them:
- Every file in `src/` starts with `--!strict`. Strict mode is what catches wrong property types, misspelled
  methods and `Enum.Font` vs `Font` mistakes against the real Roblox API definitions
  (`tools/types/globalTypes.d.luau`). When the API exists in those definitions, use it. If you're unsure whether an
  API, enum item or property exists, grep that file. Use `:: any` casts only for genuinely dynamic data.
- Put game rules in pure `src/shared/Logic/*` modules (no services, no clocks, no `Instance`s) and unit-test them
  in `tests/<feature>/*.spec.luau`. Services stay thin: validate input, call Logic, persist, replicate.
- Builders (`src/shared/Build`, `src/shared/Assets`, `src/world`) must be bake-safe (contracts §13) and are
  exercised by tests and the bake.

## Code conventions

- Luau, tabs, StyLua-formatted. Modules return a table. Server services and client controllers follow the
  shape in contracts §2 and are auto-discovered: no registration edits needed.
- Require siblings with `require(script.Parent.X)`; shared code with
  `game:GetService("ReplicatedStorage").Shared...`. No string requires inside `src/`.
- Server-authoritative everything: validate every remote argument with `Shared/Guard`; never trust client
  numbers. Name remotes `Feature.Action`. Use `Net` only (no hand-made RemoteEvents).
- Use `task.wait/spawn/delay/defer`, never `wait/spawn/delay`. Use `Shared/Util/Rng` and `Hash` for randomness
  in logic and builders (deterministic, testable). `Random.new()` is fine only in runtime-only visual code.
- Time: `Shared/Util/Time.now()` in services. Logic takes `now` as a parameter.
- UI: build with `src/client/UI/Kit` components and `UI/Theme` tokens. Support phone screens (min 44 px tap
  targets, `UIScale`, no hover-only affordances). All player-facing text comes from your feature's config or a
  `Config/Strings` table, so it can be localized later.
- No external asset ids. Everything is built from Parts, built-in materials, built-in fonts, GUI objects, and
  `rbxasset://` content that ships with the client. (Clothing template ids are optional, via `Config/ClothingIds`.)
- Fictional companies and people only. No real brands, banks, or real-world stock data.
- Keep files focused (one clear purpose each). If a file passes about 600 lines, split it into a folder module.

## Git

Work on the current branch. Don't commit from subagents unless told to; the coordinator commits.

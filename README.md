# The Street

A career-first Roblox experience: start as a college student with a randomly rolled background, recruit
into investment banking, trade a fictional market, survive performance reviews, get promoted (or fired,
then fight your way back), and branch into Private Equity, Hedge Funds, Venture Capital, Real Estate or
Corporate Development, all the way to running your own firm at level 100.

Everything in the game is built from code in this repo: buildings, offices, props, clothing, UI and
NPCs. No catalog assets are needed.

## Play it in Roblox Studio

1. Download `TheStreet.rbxl` from the latest build (see "Builds" below) and double-click it, or open it from
   Studio with **File → Open from File**.
2. Press **Play**. You spawn at the Eastbridge bus depot.
3. For testing, turn on **Game Settings → Security → Enable Studio Access to API Services**. Saving,
   leaderboards and the market secret then work in Studio. Without it the game still runs, using
   in-memory stand-ins (nothing is saved).

### One-time game settings (in Studio, after you publish the place)

| Setting | Where | Value |
|---|---|---|
| Avatar type | Game Settings → Avatar | **R15** (the in-house clothing is fitted to R15 bodies) |
| Max players | Game Settings → Places → Server Fill | 24 |
| API services | Game Settings → Security | Enable Studio Access to API Services (for testing) |
| Paid random items | Creator Dashboard → your experience → Questionnaire | Answer truthfully: Profile Reroll is a paid random item (odds are shown in-game) |

### Robux products (optional, when you're ready to sell)

The game ships with every product set to "Coming soon". To turn them on:
1. In the Creator Dashboard, open your experience → **Monetization**.
2. Create the 5 **Developer Products** (Profile Reroll, Background Rebuild, Career Reinstatement, Capital
   Reconstruction, Season Pass Premium) and the 3 **Passes** (Corner Office Collection, Office Theme Pass,
   Executive Club). Suggested prices are listed in `src/shared/Config/Products.luau`.
3. Paste each id into `src/shared/Config/Products.luau` (the `id = 0` fields), rebuild, and republish.

### Optional: sharper 2D clothing textures

The clothing already looks complete through fitted 3D pieces. If you also want painted Shirt/Pants
textures underneath, upload the generated images in `assets/clothing/` with
`tools/clothing/upload.py` (instructions in `tools/clothing/README.md`). The script writes the ids into
`src/shared/Config/ClothingIds.luau` for you.

## Builds

After each update, `build/TheStreet.rbxl` is rebuilt and attached to the pull request / shared in chat.
To build it yourself:

```bash
tools/setup.sh      # once: installs Rojo, Lune, StyLua and luau-lsp
tools/check.sh      # tests, world bake, type-check, format check, and the .rbxl build
```

To live-sync code into an open Studio place instead, install the Rojo Studio plugin and run
`rojo serve`. Run `lune run tools/bake` first, so the baked world is included.

## Editing the world by hand

The city is generated from `src/world/*` and baked into `Workspace.World`. Anything you change inside
`Workspace.World` in Studio gets replaced by the next build. To keep hand-made additions, put them in
`Workspace.Handmade`. Save that folder as a model (`.rbxm`) into `src/handmade/` and it's included in
every build.

## Project layout

| Path | What's there |
|---|---|
| `docs/superpowers/specs/` | The game design spec (every number and mechanism) |
| `docs/contracts.md` | How the code's features talk to each other |
| `docs/blueprint/` | The original design blueprint |
| `src/shared/` | Code used by both server and client: config, game rules (`Logic/`), builders (`Build/`, `Assets/`) |
| `src/server/` | Server services: saving, career, market, work, events, shop, store, leaderboards… |
| `src/client/` | Client controllers and UI screens |
| `src/world/` | World builders: campus, Wall Street, every interior |
| `tests/` | Automated tests (run with `lune run tools/test`) |
| `tools/` | Build, bake, test and check scripts |

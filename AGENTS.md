# AGENTS.md

WoW 1.12 / Turtle WoW addon. There is **no build, test, lint, or CI** — nothing to run, nothing to install. `CLAUDE.md` holds the architecture deep-dive (auto-loaded); this file adds operational gotchas.

## Conventions that break things silently

- **Every `src/**/*.lua` must start with `setfenv(1, MissingCrafts)`.** It isolates addon globals into the `MissingCrafts` table (`src/Environment.lua`). Forgetting it quietly breaks environment isolation.
- **New `.lua` files MUST be registered in `MissingCrafts.toc`** in dependency order (`Environment.lua`, `Compatibility.lua` → `db/` → `locale/` → `ui/` → `MissingCrafts.lua` last). Nothing else loads them.
- **Verification is `luac -p <file>`** (syntax only — no tests/linters; WoW APIs don't exist outside the client, so runtime testing here is impossible).
- **Never edit `lib/`** — it's vendored third-party (Ace3, LibStub, LibCrafts, LibCraftingProfessions, LibItemTooltip); updates come from upstream bumps.

## Target environment (Vanilla 1.12 + Turtle WoW, NOT retail)

- Vanilla-era API only (`Interface: 11200`). Legacy idioms are intentional: `strfind`, `strlower`, `tinsert`, `tremove`, `getglobal`, `table.setn`, `setfenv`. Don't "modernize".
- `src/Compatibility.lua` handles SuperWoW-specific spell-link prefixes.

## Localization

- `enUS` is the default locale (`NewLocale("enUS", true)` in `src/locale/enUS.lua`); `src/locale/Tools.lua` defines the `MissingCraftsLocale` type every string must belong to.
- Adding/renaming a string means updating **all 9 locale files + the `MissingCraftsLocale` shape** in `Tools.lua`. Missing keys silently resolve to nil; keep the `if L == nil then return end` guard.

## Version bumps

Version lives in **3 places** — `## Version` in `MissingCrafts.toc`, `ADDON_VERSION` in `src/Environment.lua`, and `CHANGES.md`. Keep them in sync.

## Wiring & data flow

- Entrypoint: `src/MissingCrafts.lua` `OnEnable` wires libraries → repositories → `UIManager`. `LibCraftingProfessions` events (`LCP_SKILLS_UPDATE`, `LCP_FRAME_SHOW`, `LCP_FRAME_CLOSE`) drive database + UI updates.
- New recipe sources must be added to the `CraftSource` mapping in `CraftRepository.parseSources` (`src/db/CraftRepository.lua`) plus a `craft_source_*` locale key.
- UI: `VanillaFramePool` is the frame-reuse mechanism (use it over raw `CreateFrame`); AceGUI is injected per-component, not assumed global. Frame placement offsets per (addon, frameType) are hard-coded in `src/ui/window/PlacementPolicy.lua`.
- Repos/components follow module-table + `:Create()` (returns metatable instance); edit in the `---@` annotated style.

Style: 4-space indent, LuaCATS `---@` annotations, no semicolons, no comments unless asked.
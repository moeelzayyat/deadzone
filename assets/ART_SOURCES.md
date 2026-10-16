# ART & ASSET SOURCES

Every asset, package and audio ID used in the place is recorded here before it ships. No entry, no asset. Versions are pinned; updates are a new row with the old row marked superseded.

Columns: **Asset** · **Type** (Model / Mesh / Texture / Audio / Package / Font / Image) · **Roblox asset ID** · **Origin** (Creator Store / commissioned / generated in Studio / owner-made) · **License / terms** · **Owner / creator** · **Version or date pinned** · **Used in** · **Status** (Active / Superseded / Placeholder)

| Asset | Type | Asset ID | Origin | License | Owner / creator | Pinned | Used in | Status |
|---|---|---|---|---|---|---|---|---|
| ProfileStore | Package (ModuleScript) | 109379033046155 (official library model, linked from the README and the docs tutorial) | Creator Store; source github.com/MadStudioRoblox/ProfileStore | **Apache-2.0** (LICENSE in the repo, checked 2026-10-16; no NOTICE file). Obligations: keep the `MAD STUDIO (by loleris)` header; mark any file we modify; keep a copy of the license with it. Done at insert: `ProfileStore_LICENSE` StringValue beside the module, byte-identical to the repo LICENSE (11,357 B, FNV-1a dc4aedc0). Module is **unmodified**. | loleris (Mad Studio) | **Inserted A1.1, 2026-10-16.** Store asset updated 2025-03-25T15:59:32Z. Source compared with GitHub: `ProfileStore.luau` last changed in 9580f7c (2025-03-25, "Blocking prevention for MessagingService"), unchanged at HEAD 45c9847 (2025-07-31; wally.toml 1.0.3). The store copy equals that file except whitespace-only lines (store 64,517 B / GitHub 64,654 B, 2,243 lines; identical after blanking whitespace-only lines, FNV-1a a797d1a7 both). Store copy is used as inserted (FNV-1a 1e3a6f3f). Inserted with `Sandboxed = true` by the MCP insert (DataStore, Network, ServerCommunication capabilities included); require tested in play: DataStoreState = Access. Attributes `AssetId`, `Pinned`, `License`, `SourceFNV1a` on the module. | `ServerScriptService/Server/Domains/Data/Vendor/ProfileStore` (used from A5) | Active |
| Place | Experience | place: 72812275891657 / universe: 10771233280 | owner | — | owner (user 11752219158) | created: 2026-10-16T11:35:33Z | — | Active |

## Placeholders (A1–A3)
Generated meshes/textures and primitives are recorded here too, marked `Placeholder`, so the B4.1 art pass knows exactly what to replace.

| Asset | Type | Asset ID | Origin | Used in | Status |
|---|---|---|---|---|---|
| TestArena greybox (72 parts, Evacuation Streets palette) | Model | none (primitives) | generated in Studio, owner-made, A2.2 | `ServerStorage/Arenas/TestArena` | Placeholder |
| Survivor (10 parts welded to an R15 root, teal) | Model | none (primitives) | generated in Studio, owner-made, A2.2 | `StarterPlayer/StarterCharacter` | Placeholder |

## Reference art (not shipped)
| Asset | File | Origin | License | Status |
|---|---|---|---|---|
| Mood A — Evacuation Streets, P3 | `mood/mood_A_evacuation_streets_P3.jpg` | Studio screen capture of an original primitive scene (`ServerStorage/ArtReference/MoodA_EvacuationStreets`), P0.3 | owner-made, no third-party assets | Reference |
| Mood B — Epicenter, P7 | `mood/mood_B_epicenter_P7.jpg` | Studio screen capture of an original primitive scene (`ServerStorage/ArtReference/MoodB_EpicenterP7`), P0.3 | owner-made, no third-party assets | Reference |
| Icon concept sketch A/B | `icons/icon_concept_sketch.svg` (+ `.png` preview) | hand-written SVG, P0.3 | owner-made | Concept |

## Store assets
| Asset | Variant | File in `assets/` | Uploaded ID | Status |
|---|---|---|---|---|
| Icon | A (orange/teal) | `icons/icon_A.png` | | not made |
| Icon | B (magenta/green) | `icons/icon_B.png` | | not made |
| Thumbnail 1 — P7 extraction | — | `thumbnails/t1_extraction.png` | | not made |
| Thumbnail 2 — card choice | — | `thumbnails/t2_cards.png` | | not made |
| Thumbnail 3 — four classes | — | `thumbnails/t3_classes.png` | | not made |

## Licenses — how to fill the License column
- **Creator Store packages with a source repo** (ProfileStore, type guards, UI libraries): record the repo's license (SPDX name) and its obligations, read from the LICENSE file, not from the listing text. The listing page alone is not enough.
- **Creator Store assets without a stated license** (models, meshes, images): record "Roblox Terms of Use (Creator Store), no separate license". Note the creator and the listing date. Never use such an asset where the listing or description forbids it.
- **Audio**: Creator Store audio only, uploaded by Roblox or by a licensed partner, or audio the owner holds a written license for. Record the uploader.
- **Generated in Studio** (`generate_mesh`, `generate_texture`, primitives): "generated in Studio, owner-made". Mark them `Placeholder`.
- **Commissioned**: contract date and the right to use and modify.
- Every asset also passes the no-gore rule (`docs/ART_BIBLE.md` rule 7, `docs/COMPLIANCE.md` §2). Uploaded assets are moderated whatever the experience's maturity label is.

## Rules
- Reference-game assets, UI art, names or code: never.
- Audio must be licensed for Roblox use (Creator Store audio or owner-licensed).
- Commissioned work: contract grants the owner the right to use and modify; note the contract date.
- Never silently update a Creator Store package; insert, test, add a row, mark the old row Superseded.

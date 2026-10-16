# COMPLIANCE — v0 (P0.5)

Draft answers to Roblox's **Maturity & Compliance Questionnaire**, the acknowledgment of the monetization rules in `architecture.md` §21, and the design guardrails that keep both true. The questionnaire is submitted for real before the first publish (PT.3). An experience without maturity information is restricted for all players, so PT.3 cannot pass without it.

Sources, read 2026-10-16 (neither page shows an update date):
- Creator Hub, "Content maturity and compliance": https://create.roblox.com/docs/production/promotion/content-maturity
- Creator Hub, "Paid random items policy guidelines": https://create.roblox.com/docs/production/monetization/paid-random-items
- Not read: the Help Center articles (en.help.roblox.com returned 403). Read the Age-Restricted Content Policy and the Community Standards (Roblox economy section) before PT.3.

Answers describe the **most mature content anywhere in the experience**, as the questionnaire requires. They use the approved names (`docs/CONTENT_BIBLE.md`, D-011) and the art rules (`docs/ART_BIBLE.md`, rule 7: no gore).

---

## 1. Questionnaire draft

| # | Section | Question | Draft answer | Why (what in the game drives it) |
|---|---|---|---|---|
| 1 | Violence | Does the experience depict violence? | **Yes** | Players fight infected with firearms (Tactical Rifle, Combat Shotgun, Auto Pistol), blades (Dual Machetes, Hubcap Orbit, Stop Sign), fire, explosives and shock. |
| 1a | | How intense? | **Mild** (implied or unrealistic) | The infected dissolve into particles at zero health. There is no dismemberment, no wounds and no ragdolls of bodies. Hits show a flash and damage numbers (§22 juice checklist). Downed players (`Downed`, §6.2) show no injuries; their presentation is designed later under this rule. |
| 1b | | How often? | **Repeated** | Combat is the core loop, with constant hordes for 5–8 minutes per run. |
| 2 | Blood | Does the experience depict any blood? | **No** | ART_BIBLE rule 7: no blood, no blood pools. Infection is shown as glowing eyes and veins. Hit feedback is a white or element-colored flash. Exploder spores are amber; Spitter acid is green and is an attack, not blood. |
| 3 | Fear | Scary elements that may cause fear? | **Yes** | A zombie theme: creepy infected, the Screamer's shriek, the Burrower erupting from the ground (telegraphed by a ground crack), ominous music and the extraction siren. |
| 3a | | Level? | **Mild** | Creepy NPCs, screams, suspense. The infected are pallid and stylized; there are no disfigured faces, exposed tissue or bleeding eyes (those are Moderate). |
| 3b | | How often? | **Repeated** | The infected are on screen for the whole run. |
| 4 | Crude humor | Present? | **No** | No burping, farting, vomit or toilet humor in any definition. |
| 5 | Unplayable gambling | Present? | **No** | No casino, slot-machine or betting imagery anywhere, including the hub. |
| 6 | Strong language | Depicted, or allowed in chat? | **No** | No profanity in text, voice lines or names. The chat strong-language setting stays off. |
| 7 | Romance, private spaces, adult settings | Present? | **No** | Zones are streets, a hospital, industry, a lab, a military base and a crater. No bars or clubs. |
| 8 | Alcohol | Depicted, referenced or used? | **No** | No alcohol props or references. Fire weapons are a Flame Projector, a Flare Gun and Accelerant; there is no Molotov cocktail or bottle imagery. |
| 9 | Social hangout | Is hanging out the main theme or activity? | **No** | The hub is a menu space (gear, skills, codex, deploy). The main activity is co-op combat. The title and description never call it a hangout. |
| 9a | | Private spaces? | **No** | — |
| 10 | Free-form user creation | Present? | **No** | No drawing, painting, spray paint or free text canvases. |
| 11 | Sensitive issues | Is a sensitive issue the main theme? | **No** | A fictional zombie outbreak with an invented strain. No real-world events, diseases, politics or religion. |
| 12 | Paid random items | Present? | **No** | §21 sells cosmetics at fixed prices with no Robux chests, and eggs, chests and Forge rerolls cost gameplay currency only. Premium-track bonus currency never funds a random sink (D-012, §3). |
| 12a | | Respects `ArePaidRandomItemsRestricted`? | **n/a while 12 is No.** If 12 becomes Yes: **Yes**, checked per player through `PolicyService:GetPolicyInfoForPlayerAsync`. | — |
| 13 | Paid item trading | Can users trade items they paid for? | **No** | No trading system exists in the architecture or the system registry. |
| 13a | | Respects `IsPaidItemTradingAllowed`? | **n/a** | — |
| 14 | Media | Can users share gameplay media other users see, with tools built into the experience? | **No** | The results "run card" is shown on the player's own screen. Players share it with Roblox's own capture tools. |
| 14a | | Continuously loading feeds or autoplaying audio/video? | **No** | Music and stingers are game audio, not media feeds. |
| 14b | | Can users view content captured in other experiences? | **No** | — |
| 15 | AI interaction | Can users interact with generative AI in the experience? | **No** | AI is used to build the game only, which the questionnaire excludes. |

### Expected result
**Label: Mild** (repeated mild violence, mild fear). Minimal allows only *occasional* mild violence, so a horde game cannot be Minimal. By default, Minimal and Mild experiences are playable by all age groups (Roblox Kids 5–8, Select 9–15 and 16+). Reaching the Kids and Select audiences may need extra publishing requirements, which are separate from the label (https://create.roblox.com/docs/production/publishing/kids-and-select, not yet read; read it at PT.3).

Content descriptors expected on the store page: Violence (Mild, Repeated) and Fear (Mild, Repeated).

---

## 2. Guardrails that keep these answers true

Any change below means re-answering the questionnaire before it ships. Roblox requires resubmission after any update that changes the answers. Inaccurate answers can get the label removed, which restricts the experience, and repeated inaccuracy leads to moderation.

| Answer at risk | What would change it | Rule |
|---|---|---|
| Violence: Mild | Bodies that stay after death, ragdolls, wounds, severed limbs, realistic injury decals, a single realistic finishing move | The infected dissolve at zero health. No corpse persistence and no dismemberment (ART_BIBLE rule 7). |
| Blood: No | Any splatter, even green or yellow (non-red blood still counts as "unrealistic blood") | Hit VFX are flashes, sparks and element colors only. If an ichor splash is ever wanted, re-answer question 2. Fleeting unrealistic blood keeps the label at Mild, but the answer itself changes. |
| Fear: Mild | Disfigured mouths, exposed tissue, open wounds, bleeding eyes, gore-themed bosses | Boss and elite designs pass the ART_BIBLE silhouette review with this table in hand (B4.1 art pass, PT.1 models). |
| Crude humor, alcohol, gambling: No | Joke items, emotes or props (vomit, beer, slot machines, roulette-style cosmetic reveals) | Cosmetic and emote lists are checked against this table before L1.3. |
| Strong language: No | Profane voice lines or names; turning on the chat strong-language setting | All names come from CONTENT_BIBLE. |
| Free-form creation: No | Custom-text name tags, signs or drawings | Name tags (§21.2) are a preset list. Any player-written text is filtered with `TextService` and needs a contract row first. |
| Media: No | An in-game feed of other players' run cards or clips | A shared run-card wall would change answer 14. |
| Paid random items: No | See §3 | — |

Asset moderation is separate from the label: an uploaded image, mesh or audio with realistic gore can be moderated whatever the label says. The same no-gore rule applies to every asset recorded in `assets/ART_SOURCES.md`.

---

## 3. Monetization rules (§21): acknowledged

`architecture.md` §21 and D-006 are acknowledged **as written** and are not changed here:
- Robux buys cosmetics, the battle pass premium track, supporter packs, non-gating convenience and private servers (§21.2).
- Robux never buys gear, gear chests, eggs with stat pets, in-run power, XP boosts beyond Squad bonuses or protocol multipliers (§21.3).
- Every currency (Gold, Serum, Samples, event currency) is earned from play and none is purchasable directly with Robux (§21.1).
- The fairness test answers stand (§21.4). Receipts go through `ProcessReceipt`, are idempotent and are granted only after the profile commit (§21.5).
- No anxiety mechanics: no streak wipes, loss threats or countdown pressure (project rule).

### Decisions taken while answering question 12 (D-012, decided 2026-10-16 under owner delegation, revisable)

**Outcome:** Option A for both O-1 and O-2. The §0 row and §21.2 are corrected, and answer 12 is "No". The analysis below is kept as the record.

Roblox's policy defines paid random items as random items bought **directly or indirectly** with Robux, including with "paid in-game currency". It names capsules (eggs, chests, wheels), enhancements that may fail, rerolls, and probability modifiers including pity systems. Read against that definition, two lines in the docs conflict with answering "No":

**O-1. "Cosmetic-only Robux chests" (architecture §0 table, Monetization row).** A chest bought with Robux is a paid random item even when it only holds cosmetics. §21.2 does not list chests, and §21.4 answer 3 says "no chance purchases", so the docs disagree with each other.
- Option A (recommended): sell cosmetics directly at fixed prices and correct the §0 row. Question 12 stays No, and the §21.4 answer stays true.
- Option B: keep Robux cosmetic chests. Question 12 becomes Yes, odds must be shown as percentages summing to 100% before purchase, and players for whom `ArePaidRandomItemsRestricted` is true get a fixed-price or earnable path. §21.4 answer 3 would need rewording.

**O-2. Premium battle pass "bonus currency" (§21.2).** If the premium track grants Gold, Serum or Samples, those currencies are partly bought with Robux. Eggs (Serum/Gold), gameplay chests and Forge affix rerolls (Samples) then become indirect paid random items, and the egg pity counter counts as a probability modifier.
- Option A (recommended): premium-track bonus currency is limited to a currency that only buys fixed-price items (for example the season's event currency, spent in a fixed-price cosmetic shop). Eggs, chests and rerolls stay pure play rewards, and question 12 stays No.
- Option B: keep Gold/Serum/Samples on the premium track. Question 12 becomes Yes for eggs, chests and rerolls. Odds and pity rules must be shown before the currency is spent, and restricted players need an alternative path. A fungible currency cannot tell paid coins from earned coins, so in practice the random sink would be blocked for those players.

Option A was taken for both (D-012). The answer to 12 holds while every Robux purchase is fixed-price and no Robux-derived currency reaches a random sink. Re-answer 12 if either changes.

---

## 4. When this document is revisited

| When | What |
|---|---|
| PT.3 (first publish, unlisted) | Submit the questionnaire with these answers. Read the Help Center age-restricted policy, the Community Standards and the Kids and Select requirements. Record the label and descriptors here. |
| B1 | Re-check the paid-random-item policy on the Creator Hub (§21.5) before gameplay chests and eggs. Confirm D-012 still holds. |
| L1.3 | Re-answer the §21.4 fairness test in writing (roadmap). Check every cosmetic, emote and shop item against §2. |
| Every season (L3 onward) | Re-check rating and paid-random-item rules (ROADMAP risk table, "Policy change"). Resubmit if any answer changed. |

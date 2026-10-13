# CS16Forge knife viewmodels (20 verified)

Source catalog: https://cs16forge.com/api/vitrine/list/skins/?l=en&sc=knife (741 items at acquisition). Each name links to its resource page; zip and MDL SHA-256, exact sequences, role mappings, dates, flags and converter stderr are recorded in [manifest.json](manifest.json). No license was stated in the inspected resource-page JSON-LD: `license: null` means **unknown**, not freely redistributable. The page attributes every selected skin to `community` (no individual creator named). All 20 are GoldSrc IDST v10, single sequence group, embedded textures; archives contained no executables or required texture companion MDLs. Only `v_knife.mdl` was extracted.

| Skin (mesh) | Category | Inspect sequence (index; frames/fps; seconds) | MDL bytes | Textures | Trial GLB bytes |
|---|---|---|---:|---:|---:|
| [Karambit Gamma Doppler All Phases](https://cs16forge.com/skins/knife/kerambit_gamma_doppler_all_phases/) (karambit) | inspect | inspect_1_1 (#8; 115/25; 4.6s) | 1,613,468 | 4 | 2,215,184 ✓ |
| [Talon Knife Case Hardened](https://cs16forge.com/skins/knife/talon_knife_case_hardened/) (talon) | inspect | inspect (#8; 81/30; 2.7s) | 5,528,000 | 31 | 5,469,124 ✓ |
| [Skeleton Knife Fade](https://cs16forge.com/skins/knife/skeleton_knife_fade/) (skeleton) | inspect | inspect_1 (#8; 185/30; 6.16667s) | 1,548,520 | 4 | 2,021,368 ✓ |
| [Survival Knife Case Hardened 403 Pattern Blue Gem](https://cs16forge.com/skins/knife/survival_knife_case_hardened_403_pattern_blue_gem/) (survival) | inspect | inspect_1 (#8; 250/30; 8.33333s) | 1,670,968 | 4 | 2,318,284 ✓ |
| [Nomad Knife Vanilla](https://cs16forge.com/skins/knife/nomad_knife_vanilla/) (nomad) | inspect | inspect_1 (#8; 149/30; 4.96667s) | 1,784,932 | 4 | 2,185,324 ✓ |
| [Kukri Knife Fade](https://cs16forge.com/skins/knife/kukri_knife_fade/) (kukri) | inspect | inspect_1 (#8; 182/30; 6.06667s) | 1,384,344 | 3 | 1,944,232 ✓ |
| [Shadow Daggers Fade V2](https://cs16forge.com/skins/knife/shadow_daggers_fade_v2/) (shadow daggers) | inspect | inspect_1 (#8; 122/26; 4.69231s) | 2,545,732 | 13 | 3,098,752 ✓ |
| [Ursus Knife Fade](https://cs16forge.com/skins/knife/ursus_knife_fade/) (ursus) | inspect | inspect (#8; 151/30; 5.03333s) | 1,564,104 | 15 | 2,857,784 ✓ |
| [Bayonet Paw](https://cs16forge.com/skins/knife/bayonet_paw/) (bayonet) | inspect | inspect_1 (#8; 144/30; 4.8s) | 983,816 | 4 | 2,383,092 ✓ |
| [Navaja Fade](https://cs16forge.com/skins/knife/navaja_fade/) (navaja) | inspect | inspect_1 (#8; 143/30; 4.76667s) | 1,586,912 | 4 | 2,372,188 ✓ |
| [Butterfly Knife Fade](https://cs16forge.com/skins/knife/butterfly_knife_fade/) (butterfly) | no_inspect | none (8 standard slots only) | 1,099,376 | 2 | 1,219,764 ✓ |
| [M9 Bayonet Doppler Sapphire](https://cs16forge.com/skins/knife/m9_bayonet_doppler_sapphire/) (M9 bayonet) | no_inspect | none (8 standard slots only) | 1,775,728 | 13 | 2,126,180 ✓ |
| [Huntsman Knife Blood Hound](https://cs16forge.com/skins/knife/huntsman_knife_blood_hound/) (huntsman) | no_inspect | none (8 standard slots only) | 1,645,056 | 3 | 2,179,840 ✓ |
| [Falchion Comet Sport Gloves Pandoras Box](https://cs16forge.com/skins/knife/falchion_comet_sport_gloves_pandoras_box/) (falchion) | no_inspect | none (8 standard slots only) | 1,994,972 | 8 | 2,166,108 ✓ |
| [Bowie Knife Poisonous Gas](https://cs16forge.com/skins/knife/bowie_knife_poisonous_gas/) (bowie) | no_inspect | none (8 standard slots only) | 1,596,244 | 4 | 1,601,944 ✓ |
| [Classic Knife Vanilla](https://cs16forge.com/skins/knife/classic_knife_vanilla/) (classic) | no_inspect | none (8 standard slots only) | 1,151,016 | 11 | 2,325,292 ✓ |
| [Kitchen Knife](https://cs16forge.com/skins/knife/kitchen_knife/) (kitchen knife) | no_inspect | none (8 standard slots only) | 244,272 | 4 | 940,164 ✓ |
| [Gut Knife Lavatron](https://cs16forge.com/skins/knife/gut_knife_lavatron/) (gut knife) | no_inspect | none (8 standard slots only) | 1,719,296 | 5 | 1,814,748 ✓ |
| [Flip Knife Ruby](https://cs16forge.com/skins/knife/flip_knife_ruby/) (flip knife) | no_inspect | none (8 standard slots only) | 540,652 | 4 | 1,561,396 ✓ |
| [Bayonet Doppler Phase 1](https://cs16forge.com/skins/knife/bayonet_doppler_phase_1/) (bayonet) | no_inspect | none (8 standard slots only) | 519,880 | 5 | 1,157,900 ✓ |

**Totals:** 32,497,288 MDL bytes; 43,958,668 GLB bytes. All 20 trial conversions succeeded (exit 0, no stderr). Trial GLBs live in `.orchestration/knives/glb_trial/`, archives in `.orchestration/knives/zips/`, previews in `.orchestration/knives/previews/` (all relative to repository root).

## Inspect selection and roles

The [NextClient source](https://github.com/CS-NextClient/NextClient/blob/main/nextclient/client_mini/src/inspect.cpp#L35-L88) hardcodes knife inspect to **sequence index 8**, not a sequence-name lookup. [It checks model path and sequence count](https://github.com/CS-NextClient/NextClient/blob/main/nextclient/client_mini/src/inspect.cpp#L98-L168): on non-default model paths `lookat` is sent to the server; if index 8 is outside `numseq`, no animation plays. The duration is [`numframes / fps`](https://github.com/CS-NextClient/NextClient/blob/main/nextclient/client_mini/src/inspect.cpp#L19-L32). All ten selected inspect-tagged models have an identifiable real index-8 inspect; several have additional variants at 9/10, which NextClient does **not** select by this rule. All ten untagged models have exactly eight sequences, with no inspect-like extra. F-key binding is an integration task, not included here.

Standard role slots in every chosen MDL are indices 0 idle, 1 slash1, 2 slash2, 3 draw, 4 stab, 5 stab_miss, 6 midslash1, 7 midslash2; see each `role_map` for actual labels. Exceptions: `kerambit_gamma_doppler_all_phases` and `bayonet_paw` name index 4 `backstab` and index 5 `heavy_miss`; `flip_knife_ruby` names index 4 `staber`. Index-1/2 `slash` sequences in `kitchen_knife` are only two frames each, so consider the longer `midslash` slots for primary attacks.

## Provenance and scope

The inspected JSON-LD states `author: community`, publication and modification dates for each page, but **no license**. Do not publicly distribute source MDLs or GLBs until redistribution rights are confirmed. Technically all 20 source MDLs and converted GLBs work in the smoke trial; the 5,528,000-byte Talon source and 5,469,124-byte GLB are the largest pair; the other MDLs are under 2.6 MB each. For a lean integration, commit only rights-cleared MDLs needed for actual runtime conversion **or** rights-cleared GLBs when ready for import, not both plus archival ZIPs and trial GLBs.

Rejected candidate: `stiletto_black_laminate` is untagged but its MDL has long `use_1` (151 frames) and `use_2` (119 frames) at indices 8/9, so it does not satisfy the “no inspect-like extra sequence” requirement. Substituted `kitchen_knife` (8 sequences). Its trial was not performed, and its downloaded zip/preview were removed. `combat_thanatos` was inspected as another fallback (8 sequences) but not selected; its zip/preview were removed.

## Regenerate

Run `python tools/fetch_cs16forge_knives.py` to fetch and SHA-256-verify source MDLs from the manifest (`--offline` verifies local files only); then run `python tools/mdl_to_glb.py models_src/knives/<slug>/v_knife.mdl <output>.glb` for each needed model. The source pages give **no licence** and list the author only as **“community”**; establish redistribution rights before publishing MDLs or GLBs.

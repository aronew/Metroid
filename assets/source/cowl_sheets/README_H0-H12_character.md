# Cowl character sheets — generated art drafts

14 PNGs: H0–H11 plus the two-part H12 effects sheet. Generated using the built-in image generator. Image A was the design reference; these new sheets have not been user-approved as canon. No PNG pixel manipulation was performed after generation.

The generator did not honour the requested export sizes. These files are source art for review and cleanup, not production-ready Godot sprite atlases.

| Sheet | Requested pixels | Actual pixels | Frames | Transparent pixels present |
| --- | --- | --- | --- | --- |
| H0_Look_Development | 2048x1024 | 1774x887 | 8 | yes |
| H1_Model | 2048x1024 | 1774x887 | 8 | yes |
| H2_Expressions | 2048x1024 | 1774x887 | 8 | yes |
| H3_Key_Poses | 2048x1024 | 1774x887 | 8 | yes |
| H4_Idle | 2048x2048 | 1254x1254 | 16 | yes |
| H5_Chilled_Idle | 2048x1536 | 1448x1086 | 12 | yes |
| H6_Lighting_Blunt | 2048x2048 | 1254x1254 | 16 | yes |
| H7_Smoking_Loop | 2048x1536 | 1448x1086 | 12 | yes |
| H8_Finishing_Blunt | 2048x1536 | 1448x1086 | 12 | yes |
| H9_Bong_Hit | 2048x2048 | 1254x1254 | 16 | yes |
| H10_After_Bong | 2048x2048 | 1254x1254 | 16 | yes |
| H11_Snap_Ready | 2048x1536 | 1448x1086 | 12 | yes |
| H12_Effects_a | 2048x1024 | 1774x887 | 8 | yes |
| H12_Effects_b | 2048x1024 | 1774x887 | 8 | yes |

## Remaining issues

- Repack at exact canvas sizes with 512px cells, 256px standing height, 160px beanie width and fixed anchors (256,400). Current art often fills cells too much; simply enlarging the canvas or image does not fix proportions and registration.
- H0 backdrop squares are not exact flat specified colours, and lighting/detail vary. Some front and side poses are too similar; check profile torso and both-eye head angle.
- Clean noisy alpha fringes and stray coloured/light pixels, especially around wool and smoke. All PNGs contain transparent pixels, but alpha presence is not proof of clean extraction.
- Remove warm rim accents retained from reference A. Neutral lighting, exact hex values and 3px ink are not verified.
- Keep bare hands and feet recognisable; some feet read as boots and some running hands have too many finger details. Correct near/far limb ordering, limb lengths, volume, beanie silhouette and patch consistency frame by frame.
- Back-kick cell 7 was corrected toward a rear-facing silhouette, but its mechanics, heel orientation and gaze still need review. Jab/cross differentiation remains weak.
- Eye states are not all faithful: several closed/half-lidded poses remain bright or curved. Preserve horizontal slit rules.
- Smoke-break acting and prop continuity are approximate. Some props change size or shape; the bong is not consistently set down, and the extraction/return motions need more convincing intermediate drawings. No mouth should be introduced during cleanup.
- H11 hand/prop smear timing is not fully matched to the requested cells. Effects H12 were regenerated as two sheets for separation; plume growth, ring dissolution, exact origins and 30px flame size still require checking.
- Animation loops, transitions, tick playback, foot sliding and overlap have not been tested in Godot. Timings below are requested durations, not embedded into PNGs.

## Timing

All tick durations are sixtieths of a second at 60fps. Order is left to right then top to bottom. H12_a contains original frames 1–8; H12_b contains 9–16.

- H4_Idle: [10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 4, 10, 10, 10, 10]
- H5_Chilled_Idle: [12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12]
- H6_Lighting_Blunt: [10, 10, 6, 6, 8, 6, 6, 4, 8, 6, 10, 12, 8, 8, 10, 10]
- H7_Smoking_Loop: [10, 10, 12, 12, 8, 10, 10, 10, 6, 8, 10, 20]
- H8_Finishing_Blunt: [8, 8, 6, 3, 4, 6, 8, 6, 6, 8, 10, 14]
- H9_Bong_Hit: [10, 8, 6, 8, 6, 6, 8, 6, 4, 6, 6, 6, 4, 8, 8, 6]
- H10_After_Bong: [4, 6, 6, 3, 4, 6, 6, 6, 8, 10, 8, 6, 6, 8, 10, 12]
- H11_Snap_Ready: [2, 2, 2, 2, 3, 3, 2, 2, 2, 2, 3, 3]
- H12_Effects_a: [8, 8, 8, 8, 4, 6, 8, 10]
- H12_Effects_b: [6, 8, 8, 10, 4, 10, 3, 3]

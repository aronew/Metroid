# Cowl movement, combat and effects — generated source drafts

21 PNGs cover 12 requested groups H12–H23. Longer sequences use the requested _a/_b fallback: _a contains frames 1–8; _b contains the remaining frames in reading order. Where _b has only four frames, only its first row is used. The filenames H12_Run identify this task's run sheet, distinct from the previous pack's H12 effects filenames.

Generated with the built-in image generator using the approved outfit mockup A. No PNG pixels were resized, repacked or altered programmatically. Targeted image edits corrected the run arms/lean, grid lines, opaque landing background and oversized finisher effects.

These remain art drafts. The generator did not export the requested exact pixel dimensions or reliably preserve exact cell anchors, sizes, near/far ordering and animation continuity. No Godot slicing, collision or playback test was performed.

The referenced mannequin pose guides G were not present in this task's attachments. Poses were interpreted from the written briefs. Previously generated H1/H3 sheets were drafts, not newly supplied approved references; image A was used as the visual design reference. Exact guide or model-sheet matching cannot be claimed.

## Export measurements

| File | Requested pixels | Exported pixels | Frames | Transparent pixels present |
| --- | --- | --- | --- | --- |
| H12_Run_a | 2048x1024 | 1774x887 | 8 | yes |
| H12_Run_b | 2048x1024 | 1774x887 | 4 | yes |
| H13_Start_Stop_Turn_a | 2048x1024 | 1774x887 | 8 | yes |
| H13_Start_Stop_Turn_b | 2048x1024 | 1774x887 | 8 | yes |
| H14_Jump_a | 2048x1024 | 1774x887 | 8 | yes |
| H14_Jump_b | 2048x1024 | 1774x887 | 8 | yes |
| H15_Fall_Land_a | 2048x1024 | 1774x887 | 8 | yes |
| H15_Fall_Land_b | 2048x1024 | 1774x887 | 8 | yes |
| H16_Jab | 2048x1024 | 1774x887 | 8 | yes |
| H17_Cross | 2048x1024 | 1774x887 | 8 | yes |
| H18_Spin_Back_Kick_a | 2048x1024 | 1774x887 | 8 | yes |
| H18_Spin_Back_Kick_b | 2048x1024 | 1774x887 | 4 | yes |
| H19_Air_Kick | 2048x1024 | 1774x887 | 8 | yes |
| H20_Punch_Transitions_a | 2048x1024 | 1774x887 | 8 | yes |
| H20_Punch_Transitions_b | 2048x1024 | 1774x887 | 4 | yes |
| H21_Strike_Trails_a | 2048x1024 | 1774x887 | 8 | yes |
| H21_Strike_Trails_b | 2048x1024 | 1774x887 | 4 | yes |
| H22_Impact_Flashes_a | 2048x1024 | 1774x887 | 8 | yes |
| H22_Impact_Flashes_b | 2048x1024 | 1774x887 | 4 | yes |
| H23_Strike_Flares_Soot_a | 2048x1024 | 1774x887 | 8 | yes |
| H23_Strike_Flares_Soot_b | 2048x1024 | 1774x887 | 4 | yes |

## Production cleanup required

- Repack at exact 512px cells and requested 2048px-wide canvases. Full-body size, 160px hat width, 256px standing height, foot anchor (256,400) and airborne centre (256,300) are not consistently held. Simply resizing a whole sheet will not fix sprite registration.
- Clean noisy alpha fringes and stray light/coloured pixels around characters and effects. Transparent-pixel presence is not proof of clean alpha. Some retained light accents violate neutral-light requirements.
- Run poses still need consistent 45-degree torso lean, fully trailing straight arms, open mitten hands, low foot travel and continuity between _a and _b. Hat, head, limb lengths and trouser patch side vary.
- Jump rotations and take-off timing need registration and anatomical review; beanie slouch, body volume and cloth lag vary. Falling and landing frame heights and bracing need correction.
- Differentiate the jab's near arm from the cross's far arm, retaining short natural arm length and guard. Cross chest rotation and pivot are not consistently strong enough. Some punches read like lengthened arms.
- Back-kick body direction, heel orientation, supporting foot, spotting and 360-degree recovery are approximate; air kick leg length and foot edge likewise need review against the actual pose guides.
- Several frame poses or hand states are approximate rather than exact actions. Near/far limbs, floor contacts and sole appearance need review; some feet read as footwear.
- Effects sizes, positions relative to anchor and exact palette are not numerically matched. Some flashes look more star-like or cloudy than requested; rings and shard breakup need refinement.
- The H23_b soot frames read too much like directional flares; repaint them as dispersed soft soot and flecks. Some effects contain grey or blue fringes that need removal before game tinting.
- Playback has not been checked for loops, foot sliding, motion arcs, easing, hold fidelity, smear placement, contact consistency or seamless transitions. Requested ticks are recorded below and in timings.json; they are not embedded in PNGs.

## Timing metadata

60fps; each tick is 1/60 second. Metadata frame offsets identify original sequence positions.

- H12_Run_a, original frames 1–8: [3, 3, 3, 3, 3, 3, 3, 3] ticks
- H12_Run_b, original frames 9–12: [3, 3, 3, 3] ticks
- H13_Start_Stop_Turn_a, original frames 1–8: [2, 2, 2, 2, 2, 2, 3, 4] ticks
- H13_Start_Stop_Turn_b, original frames 9–16: [4, 5, 1, 1, 2, 2, 2, 2] ticks
- H14_Jump_a, original frames 1–8: [2, 2, 3, 3, 2, 2, 2, 2] ticks
- H14_Jump_b, original frames 9–16: [2, 2, 2, 3, 4, 3, 3, 3] ticks
- H15_Fall_Land_a, original frames 1–8: [4, 4, 4, 4, 2, 3, 3, 4] ticks
- H15_Fall_Land_b, original frames 9–16: [2, 4, 6, 6, 4, 3, 4, 6] ticks
- H16_Jab, original frames 1–8: [1, 1, 1, 3, 2, 2, 3, 4] ticks
- H17_Cross, original frames 1–8: [1, 2, 1, 3, 2, 2, 3, 4] ticks
- H18_Spin_Back_Kick_a, original frames 1–8: [2, 2, 3, 2, 1, 3, 3, 2] ticks
- H18_Spin_Back_Kick_b, original frames 9–12: [2, 2, 3, 4] ticks
- H19_Air_Kick, original frames 1–8: [1, 1, 3, 3, 3, 2, 2, 3] ticks
- H20_Punch_Transitions_a, original frames 1–8: [2, 2, 2, 3, 2, 2, 2, 2] ticks
- H20_Punch_Transitions_b, original frames 9–12: [4, 4, 6, 8] ticks
- H21_Strike_Trails_a, original frames 1–8: [2, 2, 2, 2, 2, 2, 1, 2] ticks
- H21_Strike_Trails_b, original frames 9–12: [2, 2, 3, 3] ticks
- H22_Impact_Flashes_a, original frames 1–8: [2, 2, 2, 3, 2, 2, 3, 3] ticks
- H22_Impact_Flashes_b, original frames 9–12: [2, 2, 3, 4] ticks
- H23_Strike_Flares_Soot_a, original frames 1–8: [1, 2, 2, 1, 2, 2, 1, 3] ticks
- H23_Strike_Flares_Soot_b, original frames 9–12: [2, 2, 3, 4] ticks

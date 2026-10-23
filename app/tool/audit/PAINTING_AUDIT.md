# Painting audit (run 19, 2026-10-23)

- Scenes checked: 1144 (691 base + 453 role variants; variants use their base scene's art via `artOf`).
- Scenes with no painting or a missing image file: **0**.
- Scenes on a *borrowed* painting (the painting shows a different place): **54**.

| Setting | Scenes | Currently shows |
|---|---|---|
| Fennick & Rowe Homes | 16 | est_1_1→hallway, est_1_2→living, est_1_3→bank, est_2_1→bank, est_2_2→bank, est_2_3→interview, est_3_1→bank, est_3_2→living, est_3_3→kitchen, est_4_1→bathroom, est_4_2→bedroom, est_4_3→hallway, est_5_1→bank, est_5_2→living, est_5_3→interview, est_5_4→bank |
| The hospital | 5 | l2_u20_1→doctor, l2_u20_2→doctor, l2_u20_3→doctor, l2_u20_4→doctor, l3_u11_1→doctor |
| The museum | 4 | l2_u21_1→library, l2_u21_2→train, l2_u21_3→coffee, l2_u21_4→library |
| The cinema | 4 | l2_u58_1→living, l2_u58_2→living, l2_u58_3→conference, l2_u58_4→pub |
| Vida's nursery | 25 | nur_1_1→firstday, nur_1_2→bathroom, nur_1_3→eveningtea, nur_1_4→playdate, nur_2_1→bathroom, nur_2_2→eveningtea, nur_2_3→poorly, nur_2_4→park, nur_3_1→playdate, nur_3_2→playdate, nur_3_3→living, nur_3_4→playdate, nur_4_1→firstday, nur_4_2→parentsevening, nur_4_3→parentsevening, nur_4_4→poorly, nur_5_1→parentsevening, nur_5_2→living, nur_5_3→parentsevening, nur_5_4→firstday, nur_6_1→parentsevening, nur_6_2→eveningtea, nur_6_3→school, nur_6_4→parentsevening, weda_illness→poorly |

Needs new paintings (image generation needs the user's go-ahead): nursery playroom, estate-agent office (homes.webp), hospital ward, museum hall, cinema foyer; prompts are in IMAGE_PROMPTS.md. Once they exist, drop the BORROW entries in tool/match_scene_art.py and rerun it.

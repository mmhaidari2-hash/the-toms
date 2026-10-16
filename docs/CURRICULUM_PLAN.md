# The Toms — Curriculum Plan (all levels, CEFR-aligned)

Every level is a **course path**: units → lessons. A lesson = 1–2 long story dialogues (16–24 turns, two reply choices per turn, implicit recasts, culture notes, Persian) + a 3–5 minute practice set (listen-and-pick, build-the-sentence, tap-the-object-in-the-painting, fill-the-gap) + narrative spaced review of earlier words. Each unit ends with a review checkpoint (≥70% unlocks the next unit). All lines are pre-recorded with per-character British neural voices.

Content is authored as data (`app/tool/level1/u*.txt` lesson DSL → `gen.py` → scene JSON + `assets/data/course.json`), never in code.

Targets per level: ~10 units × 4–5 lessons ≈ 45 lessons, 500–700 new words, 12–20 hours.

---

## Level 1 — A0 → A1 · "Life with the Toms" (home & Chapter 1 locations; Nicola/Leslie lead)

| Unit | Location (painting) | Can-do | Grammar | Lexis (≈55 words each) |
|---|---|---|---|---|
| 1 Hello, family! | kitchen | greet, give name/age/origin, meet family | to be (I'm/you're/he's/she's), this is, my/your/his/her | greetings, family, feelings, polite words |
| 2 Breakfast time | kitchen | offer & ask for food/drink politely | Can I have…? Would you like…? I'd like…, a/an, some | food, drink, tableware, please/thank you |
| 3 Our house | living room, hallway, bedroom | describe rooms & where things are | there is/are, prepositions (in/on/under/next to/behind), plurals | rooms, furniture, household objects |
| 4 Numbers & time | kitchen clock, bus | count, tell the time, days & dates | numbers 1–100, What time is it? at/on/in + time | numbers, days, months, half past/quarter to |
| 5 My day | bedroom, bathroom | talk about routines | present simple (I/you/he/she), always/usually/never | daily verbs, bath time, school run |
| 6 Weather & clothes | muddy hallway | talk weather, dress for it | have got, imperatives, colours + adjectives | weather (chilly, drizzling, pouring), clothes, colours |
| 7 At the shops | bakery & butcher, supermarket | buy things, ask prices, pay | How much…? this/that/these/those, Can I have… | money (quid, fiver), food shopping, quantities |
| 8 Right now! | park, garden | describe what's happening | present continuous, can/can't (ability) | actions, play, nature, animals |
| 9 Body & feeling poorly | poorly (bedroom), GP | say what hurts, sympathise | I've got a…, My … hurts, should (light) | body, illness, feelings, "poorly", "bless you" |
| 10 Evening tea & weekends | evening tea, birthday | likes/dislikes, plans, celebrate | like + -ing, love/hate, questions review, possessive 's | hobbies, celebration, tea-time, plumber call |

Functions throughout: greetings (Hiya/Alright?/Morning), please/thank you/cheers/ta, sorry/excuse me/pardon, offering tea, asking for help, small talk about the weather, shopping.

## Level 2 — A1 → A2 · "Out and about" (Leslie/Ryan lead)
Locations: High Street, corner shop, café, post office, library, bus, train station, park café, school gate, pharmacy, dentist, hairdresser/barber.
Grammar: past simple (regular/irregular), going to, comparatives/superlatives, countable/uncountable, much/many, object pronouns, adverbs of manner, should/must, present perfect intro (ever/never).
Functions: directions, booking appointments, phone calls, describing past weekend, complaints (polite), invitations.

## Level 3 — A2 → B1 · "Getting things done" (Ryan/Tom lead)
Locations: GP surgery, bank, council office, job centre, letting agent, garage/MOT, supermarket self-checkout & returns, school parents' evening, restaurant, pub quiz, gym, driving lesson.
Grammar: present perfect vs past, will/going to/present continuous future, first & second conditional, modals of obligation, passives (simple), relative clauses, reported speech intro.
Functions: forms & IDs, explaining a problem, negotiating, opinions & agreeing/disagreeing, workplace basics.

## Level 4 — B1 → B2 · "Work & community" (Tom lead)
Locations: job interview, depot/workplace, NHS 111 & A&E, neighbours' dispute, community centre, volunteering, wedding, funeral/wake, football ground, seaside trip, tradesmen.
Grammar: third conditional, wish/if only, modals of deduction, narrative tenses, phrasal verbs, linking & hedging.
Functions: telling stories, persuading, small talk at work, phone etiquette, emails.

## Level 5 — B2 → C1 · "Sounding British" (Tom/Alastair lead)
Locations: university seminar, conference, dinner party, pub banter, radio phone-in, council meeting, court/jury duty, regional trips (Manchester, Glasgow, Cardiff, Newcastle).
Focus: idioms, irony & understatement, regional accents, connected speech, register switching, politeness strategies, humour.

## Delivery order
1. Level 1 complete (10 units, ~45 lessons) — in progress (Unit 1 live first).
2. Character growth over time + full role switching.
3. Levels 2–5, one unit batch per deploy; each requires new paintings for new locations (list produced per level).

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


---

# The 1000-lesson map (target)

Every lesson keeps the same bar: one full story of 16–24 turns, two reply choices per turn, implicit recasts for typical learner errors, Persian for every line and reply, culture notes and British-vs-American notes, new words feeding the practice sets and the spaced review, every line voiced. Paintings: existing places only (no new art yet); the lead character must be in the painting. Characters stay canon (William the baby, Grandad George 76 with heart failure, Weda the Nana, Ryan's timeline as is).

| Level | CEFR | Units | Lessons | Status |
|---|---|---|---|---|
| 1 | A0–A1 | 55 | 220 | 44 written |
| 2 | A1–A2 | 60 | 240 | 48 written |
| 3 | A2–B1 | 60 | 240 | 44 written |
| 4 | B1–B2 | 45 | 180 | 44 written |
| 5 | B2–C1 | 30 | 120 | 44 written |
| **Total** | | **250** | **1000** | **224 written** |

Distribution is weighted to A1–B1 (700 of 1000 lessons), where learners need the most everyday situations.


## Level 1 (A0–A1) — 220 lessons

| Unit | Title | Painting | Lessons | Status |
|---|---|---|---|---|
| U1 | Hello, family! | kitchen | Hello! I'm Nicola · This is my family · How are you? · Please, thank you, sorry | ✅ live |
| U2 | Breakfast time | kitchen | Fancy a cuppa? · What's for breakfast? · Teddy's tea party · Cooking with Nana | ✅ live |
| U3 | Our house | living | Welcome to our home · Where's Mr Buttons? · Ryan's messy room · In the garden | ✅ live |
| U4 | Numbers & time | kitchen | Counting with Nicola · How old are you? · What time is it? · On the bus | ✅ live |
| U5 | My day | bedroom | Wake up, sleepyhead! · Ryan's week · Bath time · Nana's routine | ✅ live |
| U6 | Weather & clothes | hallway | What's the weather like? · Dressing up · Getting ready for school · Knitting with Nana | ✅ live |
| U7 | At the shops | bakery | At the bakery · The supermarket · Buying trainers · The chemist | ✅ live |
| U8 | Right now! | park | At the park · Can you…? · What are you doing? · DIY with Tom | ✅ live |
| U9 | Body & feeling poorly | poorly | Head, shoulders, knees and toes · Feeling poorly · At the GP · Nana's remedies | ✅ live |
| U10 | Evening tea & weekends | eveningtea | Teatime at six · Whose is this? · Nicola's birthday · Weekend plans | ✅ live |
| U51 | A day at home | kitchen | The morning rush · Saturday chores · A parcel at the door · Bedtime battles | ✅ live |
| U57 | Colours and shapes | playdate | Painting with Mia · Sorting the socks · Shapes in the kitchen · My favourite colour | planned |
| U58 | Pets and animals | park | Feeding the ducks · The neighbour's cat · Can we have a dog? · Animals at the farm | planned |
| U59 | In the bathroom | bathroom | Brushing teeth · Washing hands · No more bubbles! · Getting dry | planned |
| U60 | Toys and games | playdate | Sharing toys · Hide and seek · The lost jigsaw piece · Tidy-up time | planned |
| U61 | Fruit and vegetables | bakery | At the greengrocer's · Five a day · Peeling an orange · Yuck, sprouts! | planned |
| U62 | Drinks | kitchen | Squash or milk? · Making a cup of tea · It's too hot! · A glass of water, please | planned |
| U63 | Lunchtime | kitchen | Making sandwiches · A packed lunch · Beans on toast · Clearing the table | planned |
| U64 | My bedroom | bedroom | Ryan's posters · Where are my socks? · Making the bed · Lights out | planned |
| U65 | Family jobs | kitchen | What does Tom do? · Leslie at work · Nana's old job · When I grow up | planned |
| U66 | Days of the week | kitchen | Monday to Sunday · Bin day · Swimming on Tuesday · What day is it today? | planned |
| U67 | Months and seasons | park | My birthday month · Autumn leaves · Snow in January · Summer holidays | planned |
| U68 | Clothes shopping | supermarket | A new coat · What size? · Trying on shoes · Too big, too small | planned |
| U69 | Feelings | living | Happy and sad · I'm scared of the dark · Feeling grumpy · Cheer up! | planned |
| U70 | Getting dressed | bedroom | Shirt or jumper? · Buttons and zips · Odd socks · Wellies on! | planned |
| U71 | Out for a walk | park | Crossing the road · The playground · Puddle jumping · Walking home | planned |
| U72 | Meeting neighbours | hallway | Hello, Mrs Khan · Borrowing some milk · The new family next door · Saying goodbye | planned |
| U73 | Phone basics | hallway | Hello, who's speaking? · Can I speak to…? · Wrong number · Call me back | planned |
| U74 | At the café | coffee | A hot chocolate, please · Eat in or take away? · Cake for Nicola · Paying the bill | planned |
| U75 | Helping at home | kitchen | Laying the table · Washing up · Feeding William · Watering the plants | planned |
| U76 | My school day | firstday | My classroom · Playtime · School dinner · Home time | planned |
| U77 | Sizes and amounts | bakery | A big loaf or a small one? · Half a dozen eggs · A bit more, please · That's enough | planned |
| U78 | The weekend market | bakery | Fresh bread · Two for a pound · Choosing flowers · Change, please | planned |
| U79 | Simple directions | bus | Left or right? · Where's the bus stop? · Next to the bank · Straight on | planned |
| U80 | Baby William | living | Nappy time · William's first word · Bottle time · Shh, he's sleeping | planned |
| U81 | Hobbies | playdate | I like drawing · Ryan plays guitar · Football in the garden · Reading with Nana | planned |
| U82 | Rainy day | hallway | It's raining again · Umbrellas and boots · Films and popcorn · Rainbow! | planned |
| U83 | Birthdays | birthday | Making a card · Wrapping a present · Blowing out candles · Thank-you notes | planned |
| U84 | Cleaning day | kitchen | Hoovering · Dusting the shelves · Where does this go? · The bins | planned |
| U85 | Simple cooking | kitchen | Scrambled eggs · Making toast · Stir it, please · Pancake Day | planned |
| U86 | At the doctor's (basics) | gp | My name and address · What's the problem? · Take this medicine · Get well soon | planned |
| U87 | Transport words | bus | By bus · By train · Walking or driving? · Riding a bike | planned |
| U88 | Asking for help | supermarket | Excuse me, can you help me? · I can't find the milk · Where's the toilet? · Thank you so much | planned |
| U89 | Numbers and money | bakery | Coins and notes · How much is it? · Counting change · Saving pocket money | planned |
| U90 | Saying what you can do | park | I can swim · Can you ride a bike? · I can't whistle · Nicola can skip | planned |
| U91 | Visitors | hallway | Come in! · Shoes off, please · Would you like a biscuit? · Thanks for coming | planned |
| U92 | Nana's house | bathroom | Nana's bath time · Nana's slippers · Old photos · Tea with Nana | planned |
| U93 | Evening routine | eveningtea | What's for tea? · Telly time · Pyjamas on · Story time | planned |
| U94 | Spelling and names | firstday | How do you spell it? · My surname · Writing my name · Letters of the alphabet | planned |
| U95 | Likes and dislikes | eveningtea | I love chips · I don't like mushrooms · Favourite food · Swap? | planned |
| U96 | Under the weather | poorly | A cold · A tummy ache · Hot water bottle · Feeling better | planned |
| U97 | Little accidents | kitchen | Oops, I spilled it! · A grazed knee · A broken cup · It's OK, don't worry | planned |
| U98 | At the post office (basics) | postoffice | A stamp, please · Posting a card · First or second class? · A parcel for Nana | planned |
| U99 | Holiday words | christmas | Christmas tree · Presents under the tree · Easter eggs · Happy New Year | planned |
| U100 | Talking about me | kitchen | My country · My languages · My family back home · My first week in Britain | planned |

## Level 2 (A1–A2) — 240 lessons

| Unit | Title | Painting | Lessons | Status |
|---|---|---|---|---|
| U11 | Last weekend | kitchen | What did you do? · A day off · When I was young · The big match | ✅ live |
| U12 | Finding your way | bakery | Excuse me, where's…? · At the post office · Which bus? · At the train station | ✅ live |
| U13 | Making plans | barber | A trim for the prom · Booking the dentist · Can Mia come to tea? · Weekend invitations | ✅ live |
| U14 | Shops & cafés | coffee | Ordering at the café · The corner shop · A takeaway night · Complaining politely | ✅ live |
| U15 | At the school gate | firstday | Meeting the teacher · Other parents · Ryan's progress · What happened at school? | ✅ live |
| U16 | Staying healthy | pharmacy | At the chemist · At the dentist · Booking a GP appointment · Home remedies | ✅ live |
| U17 | What were you doing? | library | At the library · Something happened on the bus · When Grandad was young · The power cut | ✅ live |
| U18 | On the phone | bank | Calling the bank · Ringing the surgery · A missed call · Arranging by phone | ✅ live |
| U19 | Weekends and trips | train | On the train · A day at the seaside · Planning a walk · Back to uni | ✅ live |
| U20 | Invitations and problems | restaurant | Inviting a friend · Wrong booking · Refusing politely · The leaving do | ✅ live |
| U52 | Running the house | kitchen | The washing machine's broken · The neighbour pops round · Cooking shepherd's pie · Homework help | ✅ live |
| U53 | Out on errands | gp | The 8am phone queue · The self-checkout · At the hairdresser's · Calling the vet | ✅ live |
| U101 | Registering with a GP | gp | Filling in the registration form · Proof of address · The new patient check · Choosing a pharmacy | planned |
| U102 | Library life | library | Getting a library card · Renewing books · Rhyme time for William · Using the computers | planned |
| U103 | Buses and Oyster | bus | Topping up the Oyster card · Tapping in · The bus is late · Lost property | planned |
| U104 | Food shopping | supermarket | A shopping list · Special offers · Loyalty card · Bags for life | planned |
| U105 | Takeaways | eveningtea | Ordering a curry · Fish and chips on Friday · The delivery is late · Wrong order | planned |
| U106 | Weather talk | bus | Small talk at the bus stop · Heatwave! · Frost on the car · Weather forecast | planned |
| U107 | Weekend jobs | hallway | Washing the car · Mowing the lawn · Car-boot sale · Painting the fence | planned |
| U108 | Clothes and laundry | kitchen | Hanging out the washing · Ironing a shirt · A shrunk jumper · The launderette | planned |
| U109 | Simple complaints | coffee | Cold coffee · Wrong change · A dirty table · Missing chips | planned |
| U110 | At the chemist (A2) | pharmacy | Hay fever tablets · Plasters and cream · Can I take this with…? · Collecting for Nana | planned |
| U111 | Making appointments | dentist | A check-up · Changing an appointment · Cancelling politely · Running late | planned |
| U112 | Describing people | park | What does he look like? · Lost child · My best friend · Family resemblance | planned |
| U113 | Describing places | living | My home town · Our street · A busy city · A quiet village | planned |
| U114 | Past holidays | train | Where did you go? · A rainy camping trip · The airport delay · Holiday photos | planned |
| U115 | Kids' activities | sportsday | Swimming lessons · Brownies and Scouts · Football practice · Ballet class | planned |
| U116 | The school run | firstday | Running late for school · The lollipop lady · Forgotten PE kit · After-school club | planned |
| U117 | Comparing things | supermarket | Cheaper or better? · Bigger, faster, quieter · The best café in town · Choosing a phone | planned |
| U118 | Health habits | gym | Walking more · Drinking less coffee · Sleeping better · Couch to 5K | planned |
| U119 | Recipes | kitchen | Leslie's crumble · A Sunday roast · Making a curry · Baking scones | planned |
| U120 | Party planning | birthday | Who shall we invite? · The cake order · Party games · After the party | planned |
| U121 | Asking the way | bus | To the town hall · Lost in the market · Is it far? · Following the map on the phone | planned |
| U122 | Hotel and B&B | restaurant | Checking in · Breakfast included? · The room's too noisy · Checking out | planned |
| U123 | Paying for things | bank | Card or cash? · Contactless limit · Splitting the bill · Paying a friend back | planned |
| U124 | Garden and nature | park | Planting seeds · Birdwatching · A fox in the garden · Picking blackberries | planned |
| U125 | Phone and internet | living | The Wi-Fi's down · A new phone contract · Topping up credit · Video calling home | planned |
| U126 | Neighbourhood | hallway | Bin collection day · The corner shop man · A parcel for next door · The street WhatsApp group | planned |
| U127 | Going out | restaurant | Booking a table · Ordering a starter · Vegetarian options · Tipping | planned |
| U128 | Cinema and TV | living | Choosing a film · Buying tickets online · Popcorn and seats · What did you think? | planned |
| U129 | Football fan | pub | Watching the match · Which team do you support? · Buying a ticket · The final whistle | planned |
| U130 | Rules and signs | train | No parking · Mind the gap · Quiet carriage · Keep off the grass | planned |
| U131 | Making friends | coffee | Meeting a new friend · Swapping numbers · Coffee next week? · A playdate for the kids | planned |
| U132 | Accidents and injuries | poorly | A twisted ankle · A burn in the kitchen · A wasp sting · A nosebleed | planned |
| U133 | School reports | parentsevening | Nicola's report · Reading levels · Times tables · Being kind | planned |
| U134 | Celebrations | christmas | Diwali with Priya · Eid with the neighbours · Chinese New Year · St Patrick's Day | planned |
| U135 | Charity shops | postoffice | Donating clothes · A bargain find · Volunteering for a morning · Bric-a-brac | planned |
| U136 | Tea and biscuits | eveningtea | Dunking a biscuit · How do you take it? · Builders' tea · Elevenses | planned |
| U137 | The car | driving | Filling up with petrol · Parking ticket · A flat tyre · Car wash | planned |
| U138 | Moving house (A2) | hallway | Packing boxes · Change of address · Meeting the new neighbours · Unpacking | planned |
| U139 | Lost and found | train | I've lost my wallet · Reporting a lost phone · Found it! · Thank you, stranger | planned |
| U140 | Work routines | interview | My working day · Shift work · Lunch break · Clocking off | planned |
| U141 | Free time with Ryan | bedroom | Gaming · Music · Skateboarding · A night in | planned |
| U142 | Sweets and treats | bakery | Pick and mix · Ice cream van · A treat for being good · Too much sugar | planned |
| U143 | Nature walks | park | Wellies and maps · Getting lost · A picnic · Spotting squirrels | planned |
| U144 | British breakfast | restaurant | A full English · Porridge with honey · Marmite: love it or hate it · Kippers? | planned |
| U145 | Travel tickets | train | Single or return? · Off-peak · Railcards · Seat reservation | planned |
| U146 | A trip to London | train | The Tube map · Big Ben and the Thames · Museums are free · Oyster or contactless? | planned |
| U147 | Seaside day | train | Sandcastles · Fish and chips by the sea · Seagulls! · The 2p machines | planned |
| U148 | Simple forms | library | Name, date of birth, postcode · Signing a form · Emergency contact · Ticking boxes | planned |

## Level 3 (A2–B1) — 240 lessons

| Unit | Title | Painting | Lessons | Status |
|---|---|---|---|---|
| U21 | Work and careers | interview | The second interview · Part-time jobs · Opening a business account · Big news at tea | ✅ live |
| U22 | The NHS and you | gp | Describing symptoms · Prescription questions · A dental emergency · Looking after Weda | ✅ live |
| U23 | Getting around | train | Cancelled train · Learning to drive · Sending a parcel abroad · Bus route changes | ✅ live |
| U24 | Money and paperwork | bank | A suspicious payment · The household budget · Self-checkout trouble · Official letters | ✅ live |
| U25 | School life | parentsevening | Parents' evening · A school trip form · Choosing GCSE options · A playdate problem | ✅ live |
| U26 | Social life | pub | Pub quiz night · A birthday dinner · Talking about films · Making friends in a new city | ✅ live |
| U27 | Hobbies and fitness | gym | Joining the gym · Sports day volunteer · The book club · Nicola's new hobby | ✅ live |
| U28 | Problems at home | hallway | The boiler's broken · The plumber's visit · The messy room deal · A leaky tap | ✅ live |
| U29 | Traditions | christmas | Christmas preparations · Bonfire Night treats · Nicola's birthday wishes · Remembrance Sunday | ✅ live |
| U30 | Speaking your mind | university | A seminar debate · Presenting a project · A neighbourhood problem · Looking back | ✅ live |
| U54 | When things go wrong | gp | A&E triage · Calling the school office · Reporting a stolen bike · The prescription mix-up | ✅ live |
| U149 | Hospital visits | doctor | An outpatient appointment · Visiting a patient · Hospital parking · Being discharged | planned |
| U150 | Mental health | gp | Talking to the GP about anxiety · Self-referral to talking therapy · Helping a friend · Mindfulness | planned |
| U151 | NHS 111 | gp | Calling 111 at night · The callback · Out-of-hours GP · Walk-in centre | planned |
| U152 | Eye tests and glasses | pharmacy | Booking an eye test · Choosing frames · Contact lenses · Nicola needs glasses | planned |
| U153 | Pregnancy and babies | gp | Midwife appointment · Health visitor · Baby vaccinations · Baby group | planned |
| U154 | The bank | bank | Opening an account · Overdraft · Card blocked abroad · Standing orders | planned |
| U155 | Budgeting | kitchen | Weekly food budget · Meal planning · Cutting back · Saving for a holiday | planned |
| U156 | Benefits and support | interview | Universal Credit basics · Child Benefit · Free school meals · Help with prescriptions | planned |
| U157 | Council services | library | Reporting a pothole · Missed bin collection · Parking permit · Applying for a school place | planned |
| U158 | Housing problems | hallway | Damp and mould · Repairs request · A rent increase · Getting the deposit back | planned |
| U159 | Utilities | kitchen | Switching energy supplier · Reading the meter · Water bill · Setting up broadband | planned |
| U160 | Workplace basics | interview | Your contract · Payslip questions · Calling in sick · Asking for holiday | planned |
| U161 | Job hunting | interview | Reading a job advert · Phoning about a job · Writing a cover letter · Agency work | planned |
| U162 | Job interviews (B1) | interview | Tell me about yourself · Strengths and weaknesses · Questions to ask · Following up | planned |
| U163 | At work | conference | Training day · Health and safety · The team meeting · Christmas party at work | planned |
| U164 | Driving (B1) | driving | The theory test · Motorway rules · Speed camera · A minor car accident | planned |
| U165 | Trains (B1) | train | Strike day · Replacement bus service · Missed connection · Delay Repay | planned |
| U166 | Air travel | train | Checking in online · Hand luggage · Security · Passport control | planned |
| U167 | Holidays abroad | restaurant | Booking a package holiday · Travel insurance · Currency · Holiday complaints | planned |
| U168 | Staycations | train | A caravan holiday · A cottage in Cornwall · Rainy Lake District · Camping in Wales | planned |
| U169 | School (B1) | school | Choosing a secondary school · Uniform shopping · Detention · Bullying worries | planned |
| U170 | Teenagers | bedroom | Screen time · Curfew · Pocket money negotiations · First part-time job | planned |
| U171 | Exams | school | Revision timetable · Mock exams · Results day · Resits | planned |
| U172 | College and apprenticeships | university | Open day · Choosing A levels · Apprenticeship interview · Student finance | planned |
| U173 | Shopping (B1) | supermarket | Returning a jumper · Price matching · Online order problems · Click and collect | planned |
| U174 | Customer calls | bank | Cancelling a subscription · Disputing a charge · Being put on hold · Asking for a manager | planned |
| U175 | Home improvements | hallway | Getting quotes · Builders in the house · Choosing paint · Flat-pack furniture | planned |
| U176 | Gardening | park | The allotment · Garden centre · Swapping cuttings · Slugs! | planned |
| U177 | Food culture | restaurant | Allergies at a restaurant · Afternoon tea · A pub lunch · Street food market | planned |
| U178 | Dinner guests | eveningtea | Inviting colleagues · Dietary requirements · Bring a bottle · The washing-up debate | planned |
| U179 | Sport and fitness | gym | Joining a five-a-side team · Park run · Swimming at the leisure centre · Injury | planned |
| U180 | Hobbies (B1) | library | Joining a choir · Pottery class · Learning to knit · Photography walk | planned |
| U181 | Volunteering | library | Food bank · Litter picking · Charity run · Reading volunteer | planned |
| U182 | Community life | hallway | Neighbourhood watch · Street party · The local fete · Village quiz | planned |
| U183 | Faith and festivals | christmas | Carol service · Ramadan at work · Harvest festival · Nowruz with the Toms | planned |
| U184 | Weddings | restaurant | The invitation · Choosing a present · The speeches · The dance floor | planned |
| U185 | Funerals and sympathy | living | Hearing sad news · Sending a card · The funeral · The wake | planned |
| U186 | New baby in the family | living | Visiting the new baby · Baby shower · Choosing names · Sleepless nights | planned |
| U187 | Pets (B1) | park | Adopting a rescue dog · Pet insurance · Dog walking · The cat's missing | planned |
| U188 | Technology problems | living | Forgotten password · Phone screen cracked · Online scam text · Setting up Nana's tablet | planned |
| U189 | Online life | bedroom | Online shopping · Social media rules · Group chat drama · Video call with family abroad | planned |
| U190 | Emergencies | hallway | Calling 999 · Smoke alarm · A gas smell · First aid | planned |
| U191 | Police and law | hallway | Reporting a crime · Witness statement · Lost passport · Neighbour dispute advice | planned |
| U192 | Seasons (B1) | park | Spring cleaning · Summer barbecue · Back to school in autumn · Winter illnesses | planned |
| U193 | Christmas (B1) | christmas | Secret Santa · Christmas shopping · Nativity play · Boxing Day sales | planned |
| U194 | Bank holidays | park | Easter weekend · May Day · Summer bank holiday traffic · The bank holiday barbecue | planned |
| U195 | Regional trips | train | A weekend in Edinburgh · Visiting Manchester · Cardiff Bay · York's history | planned |
| U196 | Life admin | library | Renewing a passport · Registering to vote · TV licence · Driving licence address change | planned |
| U197 | Children's health | poorly | Chickenpox · Head lice letter · Asthma inhaler · Calling school about illness | planned |

## Level 4 (B1–B2) — 180 lessons

| Unit | Title | Painting | Lessons | Status |
|---|---|---|---|---|
| U31 | A new job | conference | First day in the office · Shadowing at the conference · Probation review · Work–life balance | ✅ live |
| U32 | Workplace communication | conference | Chairing a meeting · The tricky email · Disagreeing with the boss · Office gossip | ✅ live |
| U33 | Giving back | library | Volunteering at the library · Organising a street party · Persuading a neighbour · Weda's charity shop | ✅ live |
| U34 | Home and neighbours | hallway | A noisy neighbour · Reading the tenancy agreement · Moving out plans · Getting a mortgage | ✅ live |
| U35 | Wellbeing | gp | Talking about stress · A personal training session · Advice at the pharmacy · Talking to Grandad George | ✅ live |
| U36 | Money matters | bank | Workplace pensions · A cost-of-living conversation · Should I invest? · Sending money home | ✅ live |
| U37 | Education | parentsevening | Concerns about Ryan · The talk · University applications · A child who's struggling | ✅ live |
| U38 | News and opinions | pub | Pub debate · Local news · Election day · Fake news workshop | ✅ live |
| U39 | Customer service | supermarket | Returning a faulty item · A disappointing meal · Train compensation · A scam call | ✅ live |
| U40 | Paying it forward | firstday | Meeting a newcomer · Explaining British school life · Weda's wisdom · A speech at the community awards | ✅ live |
| U55 | Bills and paperwork | kitchen | The shocking energy bill · Renting a flat · MOT at Mick's Motors · Meeting the work coach | ✅ live |
| U198 | Career moves | interview | Asking for a pay rise · Applying internally · A job offer negotiation · Handing in your notice | planned |
| U199 | Workplace issues | conference | A colleague takes credit · Flexible working request · Grievance meeting · Return to work interview | planned |
| U200 | Remote work | living | Video meeting etiquette · Working from the kitchen table · Tech failure mid-call · Hybrid rota | planned |
| U201 | Running a small business | bakery | Registering as self-employed · A difficult customer · Dealing with suppliers · Tax return deadline | planned |
| U202 | Healthcare (B2) | doctor | Explaining a long-term condition · Second opinion · Waiting list worries · Physio | planned |
| U203 | Caring for others | poorly | Becoming a carer · Respite care · Talking to social services · Care home visit | planned |
| U204 | Ageing parents | living | Grandad's memory · Lasting power of attorney · Falls at home · Downsizing | planned |
| U205 | Property | hallway | Buying a first home · The survey · Gazumped! · Exchange and completion | planned |
| U206 | Landlords and tenants | hallway | Section 21 worries · Reporting disrepair formally · Inventory disputes · Lodger agreement | planned |
| U207 | Finances (B2) | bank | Remortgaging · Credit score · Consolidating debt · ISA or pension? | planned |
| U208 | Consumer rights | supermarket | Faulty goods under the Consumer Rights Act · Refund refused · Chargeback · Small claims | planned |
| U209 | Insurance | bank | Home insurance claim · Car insurance renewal · Travel insurance claim · Pet insurance excess | planned |
| U210 | Legal matters | library | Jury service letter · Writing a will · Parking appeal · Witness in court | planned |
| U211 | Education (B2) | parentsevening | SEN support meeting · Exclusion appeal · University offers · Gap year debate | planned |
| U212 | Parenting teens | kitchen | First party · Online safety talk · Exam stress · Learning to let go | planned |
| U213 | Relationships | coffee | Making up after a row · Long-distance friendship · A new partner · Setting boundaries | planned |
| U214 | Community action | library | Saving the library · Petition to the council · Planning objection · Residents' meeting | planned |
| U215 | Environment | park | Recycling rules · Cutting energy use · Cycling to work · Local clean-up | planned |
| U216 | Media and news | pub | Discussing the headlines · Spotting misinformation · Radio phone-in · Local paper interview | planned |
| U217 | Travel (B2) | train | Cancelled flight rights · Hire car dispute · Lost luggage · Rerouting on strike day | planned |
| U218 | Sport culture | pub | The cricket explained · Rugby six nations · Wimbledon queue · Supporting a lower-league club | planned |
| U219 | Arts and culture | conference | Theatre trip · Gallery late · Festival tickets · Book launch | planned |
| U220 | Food and dining (B2) | restaurant | Sending a dish back · Wine with dinner · Hosting a dinner party · Food intolerance | planned |
| U221 | Health and lifestyle | gym | Quitting smoking · Dry January · Marathon training · Sleep clinic | planned |
| U222 | Digital life (B2) | living | Data breach email · Smart home setup · Kids and gaming spend · Deepfake scam | planned |
| U223 | Public speaking | conference | Best man speech · Leaving speech · Presenting at work · Toast at a christening | planned |
| U224 | Neighbours (B2) | hallway | Boundary fence dispute · Overgrown hedge · Parking wars · Building work next door | planned |
| U225 | Driving (B2) | driving | Speeding awareness course · Car breakdown on the motorway · Buying a used car · Electric car charging | planned |
| U226 | Celebrations (B2) | birthday | A surprise 40th · Golden wedding anniversary · Christening · Retirement do | planned |
| U227 | Bereavement | living | Registering a death · Organising a funeral · Clearing the house · Remembering together | planned |
| U228 | Immigration life | interview | Visa renewal · Life in the UK test · Bringing family over · Explaining your journey | planned |
| U229 | Health services (B2) | gp | Complaining to PALS · Changing GP · Mental health crisis line · Social prescribing | planned |
| U230 | Seasons and weather (B2) | bus | Snow day chaos · Flood warning · Heatwave at work · Storm damage | planned |
| U231 | Workplace culture | pub | Friday drinks · Office politics · Mentoring a junior · Team-building away day | planned |

## Level 5 (B2–C1) — 120 lessons

| Unit | Title | Painting | Lessons | Status |
|---|---|---|---|---|
| U41 | Reading between the lines | kitchen | What Brits really mean · Irony at the pub · Indirect refusals · Reading the room | ✅ live |
| U42 | Banter | pub | Banter at the barber's · Self-deprecation at the gym · Winding Ryan up · When banter goes too far | ✅ live |
| U43 | Regional voices | bakery | Northern expressions · Doris's stories · Accents across Britain · Arthur's London past | ✅ live |
| U44 | Idioms at work | conference | Jargon and idioms · A promotion conversation · A business pitch · Explaining idioms to Ryan | ✅ live |
| U45 | Difficult conversations | gp | Breaking difficult news · Telling the family · A difficult meeting · Weda's fears | ✅ live |
| U46 | Formal English | library | Register switching · A formal complaint meeting · Chairing a formal panel · Writing a reference | ✅ live |
| U47 | Being British | supermarket | The art of queuing · Sporting culture · Class and accent · British food debates | ✅ live |
| U48 | Telling a good story | eveningtea | The anecdote · Nicola's story · Grandad George's story · A Christmas disaster | ✅ live |
| U49 | The art of argument | university | A formal debate · Arguing with a teenager · Playing devil's advocate · Agreeing to disagree | ✅ live |
| U50 | Home | christmas | The citizenship ceremony · Ryan's goodbye · Grandad George's blessing · Christmas toast | ✅ live |
| U56 | Standing up for yourself | library | Challenging the council · A difficult choice · The noise complaint · Is this call genuine? | ✅ live |
| U232 | Negotiation | interview | Salary negotiation · Haggling over a car · Mediating siblings · Settling a dispute | planned |
| U233 | Persuasion | conference | Pitching to investors · Convincing the council · Fundraising appeal · Changing Grandad's mind | planned |
| U234 | Politeness and power | conference | Telling the boss no · Criticising tactfully · Turning down an invitation gracefully · Apologising properly | planned |
| U235 | Humour and understatement | pub | "Not bad" means great · Deadpan jokes · Taking the mickey · Laughing it off | planned |
| U236 | Regional Britain | train | Geordie banter · Glaswegian directions · Welsh valleys · Scouse humour | planned |
| U237 | Class and society | pub | The school gates divide · Posh or common? · Social mobility debate · Accent prejudice | planned |
| U238 | Politics and civic life | library | Meeting your MP · Hustings · Referendum debate at dinner · Volunteering on polling day | planned |
| U239 | Ethics and dilemmas | eveningtea | Found money · A friend's secret · Telling a white lie · Whistleblowing | planned |
| U240 | Crisis talk | doctor | Delivering bad news · Supporting a grieving friend · Mental health conversation at work · Talking to children about illness | planned |
| U241 | Professional English | conference | Running a workshop · Handling hostile questions · Writing a formal apology · Performance review | planned |
| U242 | Academic English | university | Seminar disagreement · Supervisor meeting · Plagiarism accusation · Viva practice | planned |
| U243 | Media English | conference | Live radio interview · Podcast recording · Press statement · Social media storm | planned |
| U244 | Legal and formal | library | Tribunal hearing · Mediation session · Inquest · Formal complaint to the ombudsman | planned |
| U245 | Family dynamics | christmas | Christmas tension · The inheritance talk · Coming home changed · Reconciling with a brother | planned |
| U246 | Identity | living | Two cultures at home · Becoming British · Raising bilingual children · Where's home? | planned |
| U247 | British history talk | library | The war memories · The NHS at 75 · Empire and Windrush · Changing London | planned |
| U248 | Wordplay | pub | Cryptic crossword · Pub quiz puns · Rhyming slang · Spoonerisms | planned |
| U249 | Storytelling (C1) | eveningtea | The ghost story · The holiday disaster · How we met · The one that got away | planned |
| U250 | Looking ahead | living | Life plans · Ryan's future · Weda and George's wishes · The Toms in ten years | planned |

## Delivery
Batches of ~50–100 lessons, each: `gen.py` (validates turns, line length per CEFR, leads in paintings) → audio dump → `render_voices.py` (40 s timeout, 24 kbps speech MP3) → all tests (incl. every story opens on a painting and every line has audio) → deploy → full live crawl of every lesson. Progress reported every ~200 lessons.

Infrastructure for scale: scenes ship as one `scenes_bundle.json`; voice clips are 24 kbps mono and cached on play in a persistent audio cache (not re-downloaded on each deploy). GitHub Pages caps a site at 1 GB; at ~1000 lessons the audio approaches that cap, so a second same-origin Pages repo for audio (or lower bitrate) may be needed near the end.

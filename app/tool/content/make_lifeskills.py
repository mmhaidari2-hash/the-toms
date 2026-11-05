"""Builds assets/data/lifeskills.json — IELTS Life Skills A1/B1 preparation with Mrs Ellis (level LS).
Original practice material modelled on the published test format (ielts.org sample tests); not official content.
Same schema as grammar.json: 4 teach, 3 examples, 12 practice, 5 test."""
import json, pathlib
G=lambda p,*a:{'kind':'gap','prompt':p,'answers':list(a)}
C=lambda p,*a:{'kind':'choose','prompt':p,'answers':list(a)}
O=lambda s:{'kind':'order','prompt':s,'answers':[s]}
T=lambda p,*a:{'kind':'transform','prompt':p,'answers':list(a)}
L=lambda en,fa:{'en':en,'fa':fa}
topics=[]
def top(id,title,titleFa,teach,ex,pr,te):
    assert len(teach)==4 and len(ex)==3 and len(pr)==12 and len(te)==5,id
    kinds={i['kind'] for i in pr}; assert kinds=={'gap','choose','order','transform'},(id,kinds)
    topics.append({'id':'ls_'+id,'level':'LS','title':title,'titleFa':titleFa,'teach':teach,'examples':ex,'practice':pr,'test':te,'related':[]})

top('format','How the test works','آزمون چطور برگزار می‌شود',[
 L("IELTS Life Skills tests only speaking and listening. There is no reading or writing.","آزمون IELTS Life Skills فقط گفتار و شنیدار را می‌سنجد؛ خواندن و نوشتن ندارد."),
 L("You sit with an examiner and one other test taker. You talk to both of them.","با یک ممتحن و یک داوطلب دیگر می‌نشینید و با هر دو صحبت می‌کنید."),
 L("A1 takes up to eighteen minutes, A2 up to twenty, and B1 up to twenty-two.","A1 حداکثر ۱۸ دقیقه، A2 حداکثر ۲۰ و B1 حداکثر ۲۲ دقیقه طول می‌کشد."),
 L("There is no score: you get a pass or a fail. Topics are everyday life: family, work, shopping, health, transport, housing and the weather.","نمره ندارد؛ فقط قبول یا رد. موضوع‌ها زندگی روزمره است: خانواده، کار، خرید، سلامت، حمل‌ونقل، مسکن و هوا."),
],[L("Phase one: the examiner asks about you, then you and your partner ask each other questions.","بخش اول: ممتحن دربارهٔ خودتان می‌پرسد، بعد شما و هم‌گروهتان از هم سؤال می‌کنید."),L("Phase two: you listen to two short recordings and answer questions.","بخش دوم: دو ضبط کوتاه گوش می‌دهید و به سؤال‌ها جواب می‌دهید."),L("Then you talk together about an everyday topic.","بعد با هم دربارهٔ یک موضوع روزمره صحبت می‌کنید.")],[
 C("Which skills does IELTS Life Skills test?","speaking and listening","reading and writing","all four skills"),C("Who is in the room with you?","an examiner and one other test taker","only a computer","a group of ten students"),
 C("How long is the A1 test?","up to 18 minutes","about 2 hours","45 minutes"),C("What result do you get?","pass or fail","a band score from 1 to 9","a percentage"),
 G("At B1 the test lasts up to ___ minutes.","22","18","60"),G("You talk to the examiner and to your ___.","partner","teacher","manager"),
 C("Which topic is most likely?","shopping","nuclear physics","ancient Greek poetry"),C("In phase two you…","listen to two recordings","write an essay","read a long article"),
 O("The test has two phases."),O("We talk about everyday life."),T('Make it negative: "There is a writing test."',"There isn't a writing test.","There is not a writing test.","There is no writing test."),T('Make a question: "The test is twenty minutes long."',"Is the test twenty minutes long?"),
],[C("Is there a reading paper?","No, only speaking and listening.","Yes, one hour.","Yes, but only at B1."),G("The result is pass or ___.","fail","five","fine"),C("How many test takers sit together?","two","one","six"),O("I will listen to two recordings."),T('Make a question: "You talk to your partner."',"Do you talk to your partner?")])

top('about_you','Phase 1a: talking about yourself','بخش ۱الف: صحبت دربارهٔ خودتان',[
 L("First the examiner asks simple questions: your name, where you are from, where you live, your work and your free time.","اول ممتحن سؤال‌های ساده می‌پرسد: اسم، اهل کجا، کجا زندگی می‌کنید، کار و اوقات فراغت."),
 L("Answer in a full sentence and add one more detail. Not just \"Kabul\", but \"I'm from Kabul. It's the capital.\"","با جملهٔ کامل جواب بدهید و یک جزئیات اضافه کنید: نه فقط Kabul، بلکه I'm from Kabul. It's the capital."),
 L("Listen to the tense of the question. \"What do you do?\" means your job now.","به زمان فعل سؤال دقت کنید. What do you do? یعنی شغل فعلی‌تان."),
 L("If you don't understand, it's fine to ask: \"Sorry, could you repeat that, please?\"","اگر نفهمیدید اشکالی ندارد بپرسید: Sorry, could you repeat that, please?"),
],[L("My name's Reza. I'm from Shiraz, in the south of Iran.","اسمم رضاست. اهل شیرازم، در جنوب ایران."),L("I live in a flat in Croydon with my wife and two children.","با همسر و دو بچه‌ام در یک آپارتمان در کرویدن زندگی می‌کنم."),L("In my free time I like walking in the park and cooking.","در وقت آزاد پیاده‌روی در پارک و آشپزی را دوست دارم.")],[
 C('Examiner: "Where are you from?" Best answer:',"I'm from Herat, in the west of Afghanistan.","Herat.","I am live Herat."),C('Examiner: "What do you do?" Best answer:',"I'm a delivery driver. I work five days a week.","I'm fine, thanks.","I do in the morning."),
 C('Examiner: "How long have you lived here?" Best answer:',"I've lived here for two years.","I live here two years.","Since two years."),C("You didn't hear the question. You say:","Sorry, could you repeat that, please?","What?","Again!"),
 G("I ___ in Leeds with my husband.","live","living","lives"),G("I'm ___ Tehran.","from","of","in"),G("In my free time I ___ playing football.","enjoy","enjoying","am enjoy"),G("I ___ a cleaner at a hotel.","work as","work like","am work"),
 O("I live in a small house near the station."),O("I have two daughters and a son."),T('Make it a full answer: "Name? — Sara."',"My name is Sara.","My name's Sara."),T('Add a detail: "I like cooking." (+ Persian food)',"I like cooking Persian food.","I like cooking, especially Persian food."),
],[C('Examiner: "What do you like doing at the weekend?" Best answer:',"I like visiting my friends and going to the market.","Yes, I like.","Weekend is Saturday."),G("I'm ___ Mashhad, in the north-east of Iran.","from","at","on"),O("Could you repeat the question, please?"),T('Make it a full answer: "Job? — nurse."',"I'm a nurse.","I am a nurse."),C('Examiner: "Who do you live with?" Best answer:',"I live with my wife and my son.","I live in London.","I'm living alone with."),])

top('ask_partner','Phase 1b: asking your partner questions','بخش ۱ب: سؤال پرسیدن از هم‌گروه',[
 L("The examiner gives you a topic, for example \"your partner's neighbours\". You have a minute and a half to think of questions.","ممتحن موضوعی می‌دهد، مثلاً «همسایه‌های هم‌گروه». یک دقیقه و نیم وقت دارید سؤال آماده کنید."),
 L("Use question words: who, what, where, when, how many, how often, why.","از کلمات پرسشی استفاده کنید: who، what، where، when، how many، how often، why."),
 L("Remember \"do\" and \"does\": \"Where do your neighbours come from?\"","do و does یادتان نرود: Where do your neighbours come from?"),
 L("Listen to the answer and ask a follow-up: \"Really? Why?\" This shows you are listening.","به جواب گوش دهید و سؤال دنباله‌دار بپرسید: Really? Why? این نشان می‌دهد گوش می‌دهید."),
],[L("Do you know your neighbours well?","همسایه‌هایتان را خوب می‌شناسید؟"),L("How often do you see them?","چقدر وقت‌ها می‌بینیدشان؟"),L("What's your favourite time of year, and why?","فصل محبوبتان چیست و چرا؟")],[
 G("___ do your neighbours come from?","Where","Who","How many"),G("How ___ do you go shopping?","often","much","long"),G("___ is your favourite season?","What","Where","Who"),G("___ children do they have?","How many","How much","How often"),
 C("Which question is correct?","Do you like your neighbours?","You like your neighbours?","Like you your neighbours?"),C("Which question is correct?","What does your neighbour do?","What your neighbour does?","What does your neighbour does?"),
 C("Your partner says: \"I love winter.\" Best follow-up:","Really? Why do you like it?","OK. Next question.","Winter is cold."),C("Topic: your partner's weekend. Best question:","What do you usually do at the weekend?","Weekend?","Do you weekend?"),
 O("How long have you lived there?"),O("Why do you like the summer?"),T('Make a question with "where": "They live next door."',"Where do they live?"),T('Make a question: "She sees her neighbours every day."',"Does she see her neighbours every day?"),
],[G("___ do you usually go on holiday?","Where","What","Who"),C("Which question is correct?","How often do you cook?","How often you cook?","How often do you cooks?"),T('Make a question: "He works at the hospital."',"Does he work at the hospital?"),O("What do you do in the evenings?"),C("Your partner says: \"My neighbours are noisy.\" Best follow-up:","Oh no! What do they do?","Good.","Neighbours are people."),])

top('listening','Phase 2a: listening for details','بخش ۲الف: گوش دادن برای جزئیات',[
 L("You hear two short recordings. First you answer a general question, then you listen again for details.","دو ضبط کوتاه می‌شنوید. اول یک سؤال کلی، بعد بار دوم جزئیات را گوش می‌دهید."),
 L("Read or hear the question first, then listen for key words: names, places, numbers, prices and times.","اول سؤال را بخوانید یا بشنوید، بعد دنبال کلمات کلیدی باشید: اسم، مکان، عدد، قیمت و ساعت."),
 L("Numbers are easy to mix up: thirteen and thirty, fifteen and fifty. Listen for the stress.","عددها قاطی می‌شوند: thirteen و thirty، fifteen و fifty. به تکیهٔ صدا گوش دهید."),
 L("You can make notes. Write short words, not full sentences.","می‌توانید یادداشت بنویسید؛ کلمات کوتاه، نه جملهٔ کامل."),
],[L("Listen: \"The surgery opens at half past eight, and you can book online.\"","گوش کنید: درمانگاه ساعت هشت و نیم باز می‌شود و می‌شود آنلاین وقت گرفت."),L("Listen: \"A day ticket on the bus costs five pounds fifty.\"","گوش کنید: بلیت یک‌روزهٔ اتوبوس پنج پوند و پنجاه پنس است."),L("Listen: \"I'm meeting my sister at the market on Saturday, because she wants new shoes.\"","گوش کنید: شنبه خواهرم را در بازار می‌بینم چون کفش نو می‌خواهد.")],[
 C('"The surgery opens at half past eight." When does it open?',"8:30","8:00","9:30"),C('"A day ticket costs five pounds fifty." How much is it?',"£5.50","£15.50","£5.15"),
 C('"I\'m meeting my sister at the market." Where is she going?',"to the market","to the cinema","to the station"),C('"She wants new shoes." What does the sister want?',"shoes","a coat","a phone"),
 C('"The train leaves at thirteen minutes past four." What time?',"4:13","4:30","3:13"),C("Which pair is easy to confuse?","fifteen and fifty","red and blue","Monday and May"),
 G("Write short ___, not full sentences.","notes","letters","emails"),G("Listen for the ___: thirTEEN or THIRty.","stress","colour","spelling"),
 O("Listen to the question first."),O("The shop closes at six o'clock."),T('Write the price in words: "£7"',"seven pounds","Seven pounds"),T('Write the time in words: "9:30"',"half past nine","nine thirty","Half past nine"),
],[C('"The class is on Tuesday at seven in the evening." When is the class?',"Tuesday evening","Thursday morning","Tuesday morning"),C('"It takes about forty minutes by bus." How long?',"about 40 minutes","about 14 minutes","about 4 hours"),G("First answer a general question, then listen for ___.","details","music","grammar"),T('Write the price in words: "£3"',"three pounds","Three pounds"),O("The bus stop is next to the bank.")])

top('together','Phase 2b: talking together','بخش ۲ب: گفت‌وگوی دونفره',[
 L("At the end you and your partner talk together about an everyday topic, like places you go at the weekend.","در پایان شما و هم‌گروه دربارهٔ یک موضوع روزمره حرف می‌زنید، مثلاً جاهایی که آخر هفته می‌روید."),
 L("Talk to your partner, not only to the examiner. Look at them and ask: \"What about you?\"","با هم‌گروه حرف بزنید نه فقط با ممتحن. نگاهش کنید و بپرسید: What about you?"),
 L("Agree and disagree politely: \"I agree.\" \"That's true.\" \"I'm not sure. I think…\"","مؤدبانه موافقت و مخالفت کنید: I agree. / That's true. / I'm not sure. I think…"),
 L("Give a reason with \"because\": \"I like the park because my children can play.\"","با because دلیل بیاورید: I like the park because my children can play."),
],[L("I like going to the market because it's cheap. What about you?","بازار را دوست دارم چون ارزان است. تو چی؟"),L("That's true, but it's very busy on Saturdays.","درست است، ولی شنبه‌ها خیلی شلوغ است."),L("I'm not sure. I think the park is better for children.","مطمئن نیستم. فکر می‌کنم پارک برای بچه‌ها بهتر است.")],[
 C("Best way to bring your partner in:","What about you?","Be quiet.","My turn again."),C("Polite way to disagree:","I'm not sure. I think…","You are wrong.","No, no, no."),C("Best way to agree:","That's true.","Whatever.","Fine, stop."),
 G("I like the library ___ it's quiet.","because","but","so"),G("It's cheap, ___ it's very busy.","but","because","or"),G("What do you ___?","think","thinking","thinks"),
 C("Your partner says: \"I love the beach.\" Best reply:","Me too! Which beach do you go to?","Beach.","I don't care."),C("Who should you talk to in this part?","your partner, and the examiner if asked","only the examiner","nobody"),
 O("I agree with you about the park."),O("What do you think about the market?"),T('Join with "because": "I go to the gym. It helps me relax."',"I go to the gym because it helps me relax."),T('Make it polite: "You are wrong."',"I'm not sure. I think…","I'm not sure about that.","I don't really agree."),
],[G("I prefer the cinema ___ it's warm.","because","but","or"),C("Best way to bring your partner in:","And you? What do you like doing?","Next.","I finished."),O("That's true, but it's expensive."),T('Join with "because": "We like the park. It\'s free."',"We like the park because it's free.","We like the park because it is free."),C("Polite way to disagree:","Maybe, but I think the bus is better.","No. Bus.","That's stupid."),])

top('b1_talk','B1: talk for a minute and a half','B1: یک دقیقه و نیم صحبت',[
 L("At B1 you talk on your own for about a minute and a half. Then your partner asks you three questions.","در B1 حدود یک دقیقه و نیم تنها صحبت می‌کنید، بعد هم‌گروه سه سؤال از شما می‌پرسد."),
 L("Plan a beginning, a middle and an end. Use \"first\", \"then\", \"after that\" and \"finally\".","شروع، وسط و پایان داشته باشید: first، then، after that، finally."),
 L("Join ideas with \"because\", \"so\", \"but\" and \"although\".","ایده‌ها را با because، so، but و although به هم وصل کنید."),
 L("Mix the past and the future: what you used to do, and what you are going to do.","گذشته و آینده را ترکیب کنید: کاری که قبلاً می‌کردید و کاری که قرار است بکنید."),
],[L("When I was younger, I used to play volleyball every weekend.","وقتی جوان‌تر بودم، هر آخر هفته والیبال بازی می‌کردم."),L("Although I'm very busy now, I still go swimming on Fridays.","با اینکه الان خیلی سرم شلوغ است، هنوز جمعه‌ها شنا می‌روم."),L("Next year I'm going to join a running club, so I'm buying new trainers.","سال بعد قرار است به باشگاه دو بپیوندم، برای همین کفش ورزشی نو می‌خرم.")],[
 G("When I was a child, I ___ play in the street.","used to","use to","was use to"),G("___ it was raining, we went for a walk.","Although","Because","So"),G("I was tired, ___ I went to bed early.","so","although","because"),
 G("Next month I'm ___ to start a new job.","going","go","went"),G("___, I left school. Then I started work.","First","Finally","Although"),C(W:="Which sentence is correct?","I used to live in a village.","I use to live in a village.","I used to living in a village."),
 C(W,"Although it's expensive, I love London.","Although it's expensive, but I love London.","Although expensive it, I love London."),C("Best linking word to end your talk:","Finally","Firstly","Because"),
 O("I used to work in a bakery."),O("After that, I moved to Manchester."),T('Join with "although": "It was cold. We went to the beach."',"Although it was cold, we went to the beach.","We went to the beach although it was cold."),T('Change to the past habit with "used to": "I play chess."',"I used to play chess."),
],[G("I'm ___ to visit my family in the summer.","going","go","goes"),C(W,"We moved because my husband found a job.","We moved because of my husband found a job.","Because we moved my husband found job."),O("Finally, I want to say thank you."),T('Join with "so": "The bus was late. I took a taxi."',"The bus was late, so I took a taxi."),G("When I lived in Iran, I ___ to cook every day.","used","use","using")])

top('b1_plan','B1: planning together','B1: برنامه‌ریزی دونفره',[
 L("At B1 there is a planning task. You and your partner decide something together, for example how a friend should travel.","در B1 یک کار برنامه‌ریزی هست؛ با هم‌گروه دربارهٔ چیزی تصمیم می‌گیرید، مثلاً یک دوست چطور سفر کند."),
 L("Make suggestions: \"Shall we…?\", \"Why don't we…?\", \"How about…?\", \"Let's…\"","پیشنهاد بدهید: Shall we…؟، Why don't we…؟، How about…؟، Let's…"),
 L("Compare: \"The train is faster, but the coach is cheaper.\"","مقایسه کنید: The train is faster, but the coach is cheaper."),
 L("Finish with a decision: \"So, we agree — the train is the best idea.\"","با یک تصمیم تمام کنید: So, we agree — the train is the best idea."),
],[L("Why don't we look at the prices first?","چرا اول قیمت‌ها را نگاه نکنیم؟"),L("How about the coach? It's cheaper than the train.","اتوبوس بین‌شهری چطور؟ از قطار ارزان‌تر است."),L("OK, let's choose the train, because it's quicker.","باشه، قطار را انتخاب کنیم چون سریع‌تر است.")],[
 G("___ we take the train?","Shall","Do","Are"),G("Why don't we ___ a taxi?","get","getting","to get"),G("How about ___ the bus?","taking","take","to take"),G("___ choose the cheaper one.","Let's","Let","Lets to"),
 G("The train is ___ than the coach.","faster","more fast","fastest"),G("The coach is the ___ option.","cheapest","most cheap","cheaper"),C("Best way to finish:","So, we agree: the train is best.","Bye.","I don't know, you choose."),
 C(W,"How about going on Saturday?","How about go on Saturday?","How about to go on Saturday?"),O("Why don't we book the tickets online?"),O("The train is quicker than the coach."),
 T('Make a suggestion with "Let\'s": "We take the bus."',"Let's take the bus."),T('Compare: "The bus is cheap. The train is cheaper." → one sentence with "than"',"The train is cheaper than the bus."),
],[G("Shall we ___ on Friday?","go","going","to go"),C(W,"Why don't we ask Ali?","Why we don't ask Ali?","Why don't we asking Ali?"),O("Let's meet at the station at ten."),T('Make a suggestion with "How about": "We go by car."',"How about going by car?"),G("A car is ___ comfortable than a coach.","more","most","much"),])

top('on_the_day','On the day: tips and useful phrases','روز آزمون: نکته‌ها و جمله‌های کاربردی',[
 L("Book only with the official test provider, and bring the same ID you used to book.","فقط از طریق برگزارکنندهٔ رسمی ثبت‌نام کنید و همان مدرک شناسایی ثبت‌نام را همراه ببرید."),
 L("Arrive early. Being calm helps your English.","زود برسید؛ آرامش به انگلیسی حرف زدنتان کمک می‌کند."),
 L("If you need time, say: \"That's a good question. Let me think.\"","اگر وقت لازم دارید بگویید: That's a good question. Let me think."),
 L("If you make a mistake, just correct it and continue: \"Sorry, I mean…\" Nobody expects perfect English.","اگر اشتباه کردید درستش کنید و ادامه دهید: Sorry, I mean… کسی انگلیسی بی‌نقص انتظار ندارد."),
],[L("Sorry, could you say that again, please?","ببخشید، می‌شود دوباره بگویید؟"),L("Let me think… I'd say the park, because it's free.","بگذارید فکر کنم… می‌گویم پارک، چون رایگان است."),L("Sorry, I mean Tuesday, not Thursday.","ببخشید، منظورم سه‌شنبه است نه پنجشنبه.")],[
 C("You need a moment to think. You say:","That's a good question. Let me think.","…(silence for a minute)","I don't know. Next."),C("You said the wrong day. You say:","Sorry, I mean Tuesday.","Oh no, I failed.","Forget it."),
 C("Where should you book the test?","with the official test provider","with a stranger on social media","at the post office"),C("What should you bring?","the same ID you used to book","nothing","a dictionary"),
 G("Sorry, could you ___ that again?","say","tell","speak"),G("Let me ___.","think","thinking","to think"),G("Sorry, I ___ Friday, not Monday.","mean","means","meaning"),
 C("Your partner is quiet. You say:","What do you think?","Hurry up.","Say something!"),O("Could you speak more slowly, please?"),O("Let me think for a moment."),
 T('Make it polite: "Repeat."',"Could you repeat that, please?","Sorry, could you repeat that, please?","Can you repeat that, please?"),T('Correct yourself: say you mean "nine", not "five". Start with "Sorry, I mean"',"Sorry, I mean nine.","Sorry, I mean nine, not five."),
],[C("You didn't understand a word. You say:","Sorry, what does that word mean?","What?!","…(say nothing)"),G("That's a good ___.","question","ask","asking"),O("Sorry, could you say that again?"),T('Make it polite: "Speak slowly."',"Could you speak more slowly, please?","Can you speak more slowly, please?","Could you speak slowly, please?"),C("Is it OK to make small mistakes?","Yes — correct yourself and carry on.","No — you fail at once.","Only at A1."),])

out=pathlib.Path(__file__).resolve().parents[2]/'assets/data/lifeskills.json'
out.write_text(json.dumps({'topics':topics},ensure_ascii=False,indent=1)+'\n')
print(len(topics),'topics ->',out)

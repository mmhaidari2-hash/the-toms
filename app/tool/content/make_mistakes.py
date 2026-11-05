"""Builds assets/data/mistakes.json — 'Common mistakes of Persian speakers' (Mrs Ellis).
Same schema as grammar.json. Each topic: 4 teach, 3 examples, 12 practice, 5 test."""
import json, pathlib
G=lambda p,*a:{'kind':'gap','prompt':p,'answers':list(a)}
C=lambda p,*a:{'kind':'choose','prompt':p,'answers':list(a)}
O=lambda s:{'kind':'order','prompt':s,'answers':[s]}
T=lambda p,*a:{'kind':'transform','prompt':p,'answers':list(a)}
W='Which sentence is correct?'
L=lambda en,fa:{'en':en,'fa':fa}
topics=[]
def top(id,title,titleFa,teach,ex,pr,te,rel=()):
    assert len(teach)==4 and len(ex)==3 and len(pr)==12 and len(te)==5,id
    topics.append({'id':'pm_'+id,'level':'PM','title':title,'titleFa':titleFa,'teach':teach,'examples':ex,'practice':pr,'test':te,'related':list(rel)})

top('articles','No article? Add "a" or "the"','حرف تعریف را جا نیندازید: a / an / the',[
 L("Persian has no word like \"a\" or \"the\", so we often drop them in English. Let's fix that today.","فارسی کلمه‌ای مثل a یا the ندارد؛ برای همین در انگلیسی جا می‌اندازیم. امروز درستش می‌کنیم."),
 L("Jobs need \"a\" or \"an\": not \"I am teacher\", but \"I'm a teacher\".","برای شغل a یا an لازم است: نه I am teacher، بلکه I'm a teacher."),
 L("Use \"the\" when we both know which one: \"Close the door, please.\"","وقتی هر دو می‌دانیم کدام است the می‌گوییم: Close the door, please."),
 L("Use \"an\" before a vowel sound: an apple, an hour. Use \"a\" before a consonant sound: a university.","قبل از صدای مصوت an (an hour) و قبل از صدای صامت a (a university)."),
],[L("My husband is a builder.","شوهرم بنّاست."),L("Can you open the window?","می‌شود پنجره را باز کنید؟"),L("I waited an hour at the GP surgery.","یک ساعت در درمانگاه منتظر ماندم.")],[
 G("I'm ___ nurse.","a","an","the"),G("She's ___ engineer.","an","a","the"),G("Please pass me ___ salt.","the","a","an"),
 C(W,"He's a taxi driver.","He's taxi driver.","He's an taxi driver."),C(W,"I've got an appointment.","I've got appointment.","I've got a appointment."),
 G("We live in ___ flat near the station.","a","an","the"),G("It takes ___ hour by bus.","an","a","the"),C(W,"She goes to a university in Leeds.","She goes to an university in Leeds.","She goes to university the in Leeds."),
 O("My brother is a doctor."),O("Turn off the lights, please."),T('Add the missing article: "I am student."',"I am a student.","I'm a student."),T('Add the missing article: "She bought umbrella."',"She bought an umbrella."),
],[G("My dad is ___ electrician.","an","a","the"),C(W,"I need a new phone.","I need new phone.","I need an new phone."),G("Where is ___ toilet, please?","the","a","an"),O("I'm a cleaner at the hospital."),T('Add the missing article: "He is cook."',"He is a cook.","He's a cook.")])

top('he_she','"He" or "she"? Not the same!','he یا she؟ «او» در انگلیسی دوتاست',[
 L("In Persian, one word, \"u\", means both he and she. In English we must choose.","در فارسی «او» هم برای مرد است هم زن؛ در انگلیسی باید انتخاب کنیم."),
 L("A man is \"he\", \"him\", \"his\". A woman is \"she\", \"her\", \"her\".","مرد: he، him، his. زن: she، her، her."),
 L("A thing or an animal we don't know is \"it\", \"its\".","چیز یا حیوان: it و its."),
 L("Tip: before you say it, think — man or woman? Then pick the word.","نکته: قبل از گفتن فکر کنید مرد است یا زن، بعد کلمه را انتخاب کنید."),
],[L("My sister is a dentist. She works in Croydon.","خواهرم دندانپزشک است. او در کرویدن کار می‌کند."),L("Tom loves his bus.","تام اتوبوسش را دوست دارد."),L("I called my mum and told her the news.","به مادرم زنگ زدم و خبر را به او گفتم.")],[
 G("My wife is tired. ___ works nights.","She","He","It"),G("Ask Tom. ___ knows the way.","He","She","It"),G("Leslie lost ___ keys.","her","his","its"),
 G("I saw William and gave ___ the book.","him","her","he"),C(W,"My mother lives with her sister.","My mother lives with his sister.","My mother lives with he sister."),
 C(W,"Ryan is late. He missed his bus.","Ryan is late. She missed her bus.","Ryan is late. He missed her bus."),G("The cat is eating ___ food.","its","his","it's"),G("Maisie said ___ was hungry.","she","he","her"),
 O("My daughter loves her school."),O("Tell him I'm sorry."),T('Fix it (talking about a woman): "He is my manager, his name is Sara."',"She is my manager, her name is Sara.","She's my manager, her name is Sara.","She's my manager. Her name is Sara."),T('Fix it (Ali is a man): "Ali lost her phone."',"Ali lost his phone."),
],[G("My son broke ___ arm.","his","her","its"),G("Nicola? I'll call ___ later.","her","him","she"),C(W,"Ali's mum is a teacher. She teaches maths.","Ali's mum is a teacher. He teaches maths.","Ali's mum is a teacher. His teaches maths."),O("He gave her his number."),G("Your uncle is here. ___ is waiting outside.","He","She","Her")])

top('word_order','Word order: subject, verb, object','ترتیب کلمات: فاعل + فعل + مفعول',[
 L("Persian puts the verb at the end. English puts it right after the subject.","فارسی فعل را آخر جمله می‌گذارد؛ انگلیسی درست بعد از فاعل."),
 L("Not \"I English study\", but \"I study English\".","نه I English study، بلکه I study English."),
 L("Adjectives go before the noun: \"a red car\", not \"a car red\".","صفت قبل از اسم می‌آید: a red car، نه a car red."),
 L("Time usually goes at the end: \"I go to work every day.\"","زمان معمولاً آخر جمله می‌آید: I go to work every day."),
],[L("I bought a new coat yesterday.","دیروز یک کت نو خریدم."),L("She speaks English very well.","او انگلیسی را خیلی خوب صحبت می‌کند."),L("We visited my aunt last weekend.","آخر هفتهٔ پیش به خاله‌ام سر زدیم.")],[
 C(W,"I drink tea every morning.","I tea every morning drink.","I every morning tea drink."),C(W,"She has a big house.","She has a house big.","She a big house has."),
 O("We watch TV in the evening."),O("He bought a blue jumper."),O("I learn English at college."),O("My son plays football on Saturdays."),
 C(W,"I like British food very much.","I like very much British food.","I very much like food British."),C(W,"They live in a small flat.","They in a small flat live.","They live in a flat small."),
 T('Fix the order: "I my keys lost."',"I lost my keys."),T('Fix the order: "She a dress red bought."',"She bought a red dress."),O("Can you help me with this form?"),G("I ___ every morning.","drink tea","tea drink","tea every drink"),
],[O("I go to the gym twice a week."),C(W,"We need a bigger car.","We need a car bigger.","We a bigger car need."),T('Fix the order: "I English study."',"I study English."),O("She cooked a delicious meal."),C(W,"I saw an old friend yesterday.","I yesterday saw a friend old.","I an old friend saw yesterday.")])

top('questions','Questions need "do", "does" or a swap','سؤال‌سازی: do / does یا جابه‌جایی',[
 L("In Persian a question can sound just like a statement. In English we change the words.","در فارسی سؤال گاهی فقط با لحن است؛ در انگلیسی ساختار جمله عوض می‌شود."),
 L("With \"be\" and \"can\", swap them: \"You are ready\" becomes \"Are you ready?\"","با be و can جایشان را عوض کنید: Are you ready?"),
 L("With other verbs, add \"do\" or \"does\": \"Where do you live?\", not \"Where you live?\"","با فعل‌های دیگر do یا does اضافه کنید: Where do you live?"),
 L("After \"does\", the verb has no -s: \"Does she work?\", not \"Does she works?\"","بعد از does فعل s نمی‌گیرد: Does she work?"),
],[L("Where do you work?","کجا کار می‌کنید؟"),L("Does your son go to school?","پسرتان مدرسه می‌رود؟"),L("Can I pay by card?","می‌توانم با کارت پرداخت کنم؟")],[
 G("Where ___ you live?","do","does","are"),G("___ she speak English?","Does","Do","Is"),G("What time ___ the shop open?","does","do","is"),
 C(W,"Are you married?","You are married?","Do you married?"),C(W,"Does he work here?","Does he works here?","He works here?"),C(W,"How much does it cost?","How much it costs?","How much is it cost?"),
 O("Where do you come from?"),O("Can you speak more slowly?"),T('Make a question: "You like tea."',"Do you like tea?"),T('Make a question: "She lives in Leeds."',"Does she live in Leeds?"),
 G("___ you ready?","Are","Do","Does"),O("What does this word mean?"),
],[G("How ___ you spell your name?","do","does","are"),C(W,"Do you have an appointment?","You have an appointment?","Have you an appointment do?"),T('Make a question: "He works on Sundays."',"Does he work on Sundays?"),O("Where can I park my car?"),C(W,"What does she do?","What she does?","What does she does?")])

top('be_have','"I\'m 30", not "I have 30 years"','I\'m 30 نه I have 30 years — be و have',[
 L("Some Persian phrases use \"have\" where English uses \"be\", and the other way round.","بعضی عبارت‌ها در فارسی با «داشتن» است ولی در انگلیسی با be، و برعکس."),
 L("Age uses \"be\": \"I'm thirty\", not \"I have thirty years\".","سن با be: I'm thirty، نه I have thirty years."),
 L("Feelings like \"agree\" are verbs: \"I agree\", not \"I am agree\".","agree فعل است: I agree، نه I am agree."),
 L("But: \"I'm hungry\", \"I'm cold\", \"I'm right\" — these use \"be\".","ولی: I'm hungry، I'm cold، I'm right با be هستند."),
],[L("My daughter is seven.","دخترم هفت سالش است."),L("I agree with you.","با شما موافقم."),L("I'm cold. Can you close the window?","سردم است. پنجره را می‌بندید؟")],[
 C(W,"I'm 35.","I have 35 years.","I am 35 years."),C(W,"I agree.","I am agree.","I agreed am."),G("My son ___ ten years old.","is","has","have"),
 G("I ___ hungry. Let's eat.","'m","have","has"),C(W,"Are you cold?","Do you have cold?","Have you cold?"),C(W,"She's right.","She has right.","She have right."),
 G("I ___ with your idea.","agree","am agree","agreeing"),G("We ___ three children.","have","are","has"),O("How old is your daughter?"),O("I don't agree with him."),
 T('Fix it: "I have 40 years."',"I'm 40.","I am 40.","I'm 40 years old.","I am 40 years old."),T('Fix it: "He is agree."',"He agrees."),
],[C(W,"How old are you?","How many years do you have?","How old do you have?"),G("I ___ sleepy.","'m","have","has"),T('Fix it: "We are agree."',"We agree."),G("My mum ___ sixty.","is","has","have"),O("I'm afraid of dogs.")])

top('plurals','Plurals: "two books", no "informations"','جمع: two books — و information بدون s',[
 L("In Persian, after a number the noun stays singular: \"do ketab\". In English we add -s: \"two books\".","در فارسی بعد از عدد اسم مفرد می‌ماند (دو کتاب)؛ در انگلیسی s می‌گیرد: two books."),
 L("Some words never take -s: information, advice, furniture, luggage, homework, news.","بعضی اسم‌ها هرگز s نمی‌گیرند: information، advice، furniture، luggage، homework، news."),
 L("For these, say \"some advice\" or \"a piece of advice\", and use \"much\", not \"many\".","برای این‌ها بگویید some advice یا a piece of advice، و much نه many."),
 L("\"People\" is already plural: \"people are\", not \"peoples is\".","people خودش جمع است: people are."),
],[L("I have three children.","سه بچه دارم."),L("Can you give me some information?","می‌شود کمی اطلاعات بدهید؟"),L("The news is good today.","خبرهای امروز خوب است.")],[
 G("I bought two ___.","tickets","ticket","ticketes"),C(W,"She gave me some good advice.","She gave me some good advices.","She gave me an advice."),C(W,"I need more information.","I need more informations.","I need an information."),
 G("There are five ___ in the room.","people","peoples","person"),G("How ___ luggage do you have?","much","many","a"),C(W,"We bought new furniture.","We bought new furnitures.","We bought a furniture."),
 G("My son has a lot of ___ tonight.","homework","homeworks","a homework"),G("I've got three ___.","brothers","brother","brotheres"),O("Can I have two coffees, please?"),O("The news is on at six."),
 T('Fix it: "I have two daughter."',"I have two daughters.","I've got two daughters."),T('Fix it: "Thanks for the informations."',"Thanks for the information."),
],[G("We waited for ten ___.","minutes","minute","minuts"),C(W,"Let me give you some advice.","Let me give you some advices.","Let me give you an advice."),G("How ___ people came?","many","much","lot"),T('Fix it: "She bought three apple."',"She bought three apples."),O("Our luggage is very heavy.")])

top('prepositions','Prepositions: in, on, at, to, with','حرف اضافه: in، on، at، to، with',[
 L("Prepositions don't match Persian one-to-one, so learn them in chunks.","حرف اضافه‌ها یک‌به‌یک با فارسی جور نیستند؛ آن‌ها را تکه‌تکه حفظ کنید."),
 L("Time: at 9 o'clock, on Monday, in June, in the morning, at the weekend.","زمان: at 9، on Monday، in June، in the morning، at the weekend."),
 L("Common chunks: married to, angry with, depend on, listen to, wait for.","تکه‌های رایج: married to، angry with، depend on، listen to، wait for."),
 L("Not \"married with\", not \"depend to\", not \"listen music\".","نه married with، نه depend to، نه listen music."),
],[L("My appointment is on Tuesday at ten.","وقت من سه‌شنبه ساعت ده است."),L("She's married to a Scottish man.","او با یک مرد اسکاتلندی ازدواج کرده."),L("I'm waiting for the bus.","منتظر اتوبوسم.")],[
 G("The class starts ___ 9 o'clock.","at","on","in"),G("I was born ___ 1990.","in","on","at"),G("See you ___ Friday!","on","in","at"),
 C(W,"She's married to my cousin.","She's married with my cousin.","She's married by my cousin."),C(W,"It depends on the weather.","It depends to the weather.","It depends of the weather."),C(W,"I listen to the radio.","I listen the radio.","I listen at the radio."),
 G("We're waiting ___ the doctor.","for","to","at"),G("Don't be angry ___ me!","with","from","to"),G("I work ___ the morning.","in","on","at"),O("I'll see you at the weekend."),
 T('Fix it: "I am waiting the train."',"I am waiting for the train.","I'm waiting for the train."),T('Fix it: "He is married with Sara."',"He is married to Sara.","He's married to Sara."),
],[G("The shop closes ___ Sundays.","on","in","at"),C(W,"Can you wait for me?","Can you wait me?","Can you wait to me?"),G("We moved here ___ March.","in","on","at"),T('Fix it: "I listen music every day."',"I listen to music every day."),O("Are you angry with me?")])

top('tenses','Past and present perfect: "I\'ve lived here since…"','زمان گذشته و حال کامل',[
 L("Persian often uses the present for something that started in the past. English uses the present perfect.","فارسی برای کاری که از گذشته شروع شده گاهی حال می‌گوید؛ انگلیسی حال کامل."),
 L("Not \"I live here since 2020\", but \"I've lived here since 2020\".","نه I live here since 2020، بلکه I've lived here since 2020."),
 L("With a finished time (yesterday, last week, in 2019) use the past: \"I went yesterday\".","با زمان تمام‌شده (yesterday، last week) گذشتهٔ ساده: I went yesterday."),
 L("Not \"Yesterday I go\": the verb must change — went, saw, bought.","نه Yesterday I go؛ فعل عوض می‌شود: went، saw، bought."),
],[L("I've lived in London for five years.","پنج سال است در لندن زندگی می‌کنم."),L("I saw the doctor last Monday.","دوشنبهٔ پیش دکتر رفتم."),L("Have you ever been to Scotland?","تا حالا اسکاتلند رفته‌ای؟")],[
 C(W,"I've worked here since May.","I work here since May.","I am working here since May."),G("Yesterday I ___ to the bank.","went","go","have gone"),G("She ___ in the UK for three years.","has lived","lives","is living"),
 C(W,"I bought this coat last week.","I have bought this coat last week.","I buy this coat last week."),G("We ___ each other since school.","have known","know","are knowing"),G("Last night I ___ a film.","watched","watch","have watched"),
 C(W,"How long have you been here?","How long are you here?","How long you are here?"),O("I've never been to Wales."),O("We moved here two years ago."),G("___ you ever tried fish and chips?","Have","Did","Do"),
 T('Fix it: "I live here since 2021."',"I've lived here since 2021.","I have lived here since 2021."),T('Fix it: "Yesterday I see my friend."',"Yesterday I saw my friend."),
],[G("He ___ his job in 2022.","started","has started","starts"),C(W,"I've known her for ten years.","I know her for ten years.","I am knowing her for ten years."),T('Fix it: "Last week I buy a car."',"Last week I bought a car."),O("Have you finished your homework?"),G("They ___ married since 2015.","have been","are","were")])

top('sounds','Sounds: w/v, th, and no extra "e"','تلفظ: w و v، صدای th، و «اِ» اضافه نگذارید',[
 L("Persian has one sound between \"w\" and \"v\". In English they change the meaning: wine and vine.","فارسی بین w و v یک صدا دارد؛ در انگلیسی معنی را عوض می‌کنند: wine و vine."),
 L("For \"w\", round your lips like a kiss. For \"v\", touch your top teeth on your bottom lip.","برای w لب‌ها را غنچه کنید؛ برای v دندان بالا را روی لب پایین بگذارید."),
 L("For \"th\", put your tongue between your teeth: think, three, this, mother.","برای th زبان را بین دندان‌ها بگذارید: think، three، this."),
 L("Don't add a vowel before \"s\": say \"school\", \"station\", \"Spain\" — not \"eschool\", \"estation\".","قبل از s صدای «اِ» نگذارید: school نه اِسکول، station نه اِستیشن."),
],[L("We went to the west of Wales.","به غرب ولز رفتیم."),L("I think there are three of them.","فکر کنم سه تا هستند."),L("The station is near my school.","ایستگاه نزدیک مدرسهٔ من است.")],[
 C("Which word is a drink made from grapes?","wine","vine","vain"),C("Which word fits: \"It's ___ cold today.\"","very","wary","weary"),C("Which word is a number?","three","tree","free"),
 C("Which word means the opposite of \"thin\"?","thick","sick","tick"),C("A car has four of these. Which word?","wheels","veals","feels"),C("Which word means \"not dry\"?","wet","vet","bet"),
 G("Our cat went to the ___ for an injection.","vet","wet","bet"),T('Write the number that comes after two (in letters):',"three"),C("Which spelling is right?","station","estation","istation"),
 C("Which spelling is right?","school","eschool","iskool"),O("I think it is Thursday."),O("We visited Wales in the winter."),
],[C("Which word is a big group of water moving to the beach?","wave","vave","fave"),C("Which word means a road you can drive on? (lips rounded)","way","vay","bay"),C("Which word is the day after Wednesday?","Thursday","Sursday","Tursday"),C("Which spelling is right?","Spain","Espain","Ispain"),O("Three of us went to the west.")])

top('polite','Sounding polite: "Could I…?" not "Give me"','مؤدبانه حرف زدن: Could I… به‌جای Give me',[
 L("A direct order can sound rude in British English, even when you don't mean it.","در انگلیسی بریتانیایی دستور مستقیم حتی بی‌منظور هم بی‌ادبانه به نظر می‌رسد."),
 L("Not \"Give me a coffee\", but \"Could I have a coffee, please?\"","نه Give me a coffee، بلکه Could I have a coffee, please?"),
 L("Use \"please\", \"thank you\", and \"sorry\" a lot — more than in Persian.","please، thank you و sorry را زیاد بگویید؛ بیشتر از فارسی."),
 L("To ask for help: \"Could you…?\", \"Would you mind…?\", \"Excuse me, …\"","برای کمک خواستن: Could you…؟، Would you mind…؟، Excuse me…"),
],[L("Could I have a glass of water, please?","می‌شود یک لیوان آب بدهید، لطفاً؟"),L("Excuse me, could you help me?","ببخشید، می‌شود کمکم کنید؟"),L("Would you mind opening the window?","زحمت می‌کشید پنجره را باز کنید؟")],[
 C("Which is the most polite?","Could I have the bill, please?","Give me the bill.","Bill!"),C("Which is the most polite?","Excuse me, where is the toilet?","Where is toilet?","Toilet where?"),C("Which is the most polite?","Would you mind waiting a moment?","Wait.","You wait now."),
 G("___ I have a receipt, please?","Could","Give","Do"),G("Would you mind ___ the door?","closing","close","to close"),G("___ me, is this seat free?","Excuse","Sorry for","Pardon to"),
 C("Someone holds the door for you. You say:","Thank you.","OK.","Good."),C("You bump into someone. You say:","Sorry!","Careful!","Why?"),O("Could you say that again, please?"),O("Could I have a coffee, please?"),
 T('Make it polite: "Give me a ticket."',"Could I have a ticket, please?","Can I have a ticket, please?"),T('Make it polite: "Help me."',"Could you help me, please?","Can you help me, please?","Excuse me, could you help me?"),
],[C("Which is the most polite?","Could you speak more slowly, please?","Speak slowly.","Slowly!"),G("Would you ___ helping me with this bag?","mind","like","want"),T('Make it polite: "Give me water."',"Could I have some water, please?","Can I have some water, please?","Could I have water, please?"),O("Excuse me, could you help me?"),C("A shop assistant helps you. You say:","Thanks very much.","Fine.","Yes.")])

out=pathlib.Path(__file__).resolve().parents[2]/'assets/data/mistakes.json'
out.write_text(json.dumps({'topics':topics},ensure_ascii=False,indent=1)+'\n')
print(len(topics),'topics ->',out)

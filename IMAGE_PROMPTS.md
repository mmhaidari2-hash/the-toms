# Scene illustrations still needed (same warm painterly style as kitchen.webp / birthday.webp)
Drop each as app/assets/places/<id>.webp (1280px wide, quality 80), then in assets/data/places.json set
"image":"assets/places/<id>.webp", "aspect": w/h, and a "rect":[x,y,w,h] (0..1) per hotspot over each person.
Style prefix: "Warm painterly realistic illustration, soft golden light, cosy British setting, same style and characters as reference images".
- living: Leslie (brown bun, floral dress) on a sofa holding a teddy, William on rug.
- bathroom: Maggie (grey dress, white apron) bathing baby William, bubbles, rubber duck.
- school: Mr Patel (South Asian teacher, glasses, green jumper) at a form-room desk; Ryan (blue jumper) arriving late.
- park: Nicola (blonde, teddy) on swings in Victoria Park, duck pond behind.
- supermarket: small London corner shop/Tesco Express aisle; cashier Priya (blue uniform, bun) at till; Ryan with basket.
- bedroom: Ryan gaming on a sofa with controller, posters.
- coffee: café counter, barista Callum (ginger, green apron); Leslie ordering.
- dentist / library (Mr Bennett, grey hair, glasses, maroon cardigan; Maggie) / gp & doctor (Dr Okafor, Black male GP, white coat).
- bus: inside red London double-decker, Tom in navy bus-driver uniform driving; Doris (elderly, white hair, glasses, lilac coat) front seat.
- bank (Siân, auburn bob, navy blazer) / interview (Ms Clarke, dark bob, charcoal suit).
- university & conference: Alastair (Scottish, ginger beard, tweed jacket) leading a seminar / on stage Q&A.
- pub: The Red Lion pub quiz night, Alastair and Tom at a table with pints and answer sheet.

# Added 2026-10-17: living-town map + new everyday places
## Detailed town-map painting (replaces assets/places/map.webp; keep 16:9, 2560×1440, then re-place spots in tool/make_spots.py)
"Warm painterly realistic illustration, soft golden light, bird's-eye isometric view of a London borough (Hackney), same style as map.webp.
Every building clearly readable with a painted shop sign: the Toms' red-brick terraced house (front, centre-bottom); Mia's house; a red 38
double-decker bus at a bus stop; St Mary's primary school with playground; Vida's Nursery (colourful, small garden); London Fields park with
pond and swings; an Overground/Tube station with roundel sign and clock tower; Callum's café (red awning); The Copper Kettle restaurant;
Dawson's Pharmacy (green cross); a row of small shops (bakery, butcher, greengrocer, Sal's barber pole) and a Saturday market; a big
supermarket with car park and trolleys; a shopping centre / retail park with Primark- and Argos-style fronts (no real logos); the library &
Hackney Service Centre (council); a post office (red sign, post box); a bank; Mare Street GP surgery & dentist; Homerton Hospital (A&E sign,
ambulance); a museum with columns; a cinema; a gym; The Red Lion pub; Mick's Motors garage + petrol station; offices (job interviews); a
university campus. Leave a calm strip of sky at the top (UI overlays it). No real brand logos, no text other than short shop names."
## New scene paintings (lessons currently borrow the nearest painting)
- tube: Underground platform, roundel, train arriving, Maya (train conductor, TfL uniform) and Tom; escalator in background. (U107; now uses `train`)
- hospital: Homerton outpatients reception + ward bay; Tom with George (76, cardigan, walking stick) in a hospital bed; nurse. (U108; now uses `doctor`)
- museum: Natural History Museum hall with dinosaur skeleton, Nicola and William looking up, Tom with umbrella. (U109; now uses `train`/`restaurant`)
- bigsupermarket: large Tesco/Sainsbury's/Asda-style aisles, self-checkout ("unexpected item"), staff member (new character) helping Ryan. (planned)
- shoppingcentre: indoor shopping centre/retail park, value-clothes shop fitting rooms, catalogue-shop collection counter; Leslie, Nicola, shop assistant. (planned)
- petrol: petrol station forecourt at Mick's Motors, pump 4, kiosk; Tom and Ryan (learner driver) with the car. (planned)
- phoneshop: mobile phone shop, display tables, adviser (new character), Ryan choosing a SIM-only deal. (planned)
- council: Hackney Service Centre counter, Ms Ward (council officer), Maggie with letters. (now uses `library`)
- cinema: cinema foyer with popcorn and ticket screens, Ryan and friends. (planned)

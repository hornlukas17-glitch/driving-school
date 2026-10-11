-- Driving lessons: each lesson is a route of waypoints with instructor instructions.
-- x/z = map position, r = radius to reach it, t = what the instructor says when this point is next.
local HZ = -520

local START = {
	{ x = 550, z = 40, t = "Drive out of the parking bay and onto the street. Signal right (C), then turn right." },
	{ x = 700, z = 40, t = "Junctions without signs: right before left, drive slowly! At the next intersection, turn left." },
	{ x = 700, z = 0, t = "STOP sign at the exit: stop completely, then turn left onto the country road." },
}
local HEIMWEG = {
	{ x = 700, z = 0, t = "Follow the country road. At the gate, turn right into the residential area." },
	{ x = 700, z = 40, t = "Residential area, 30 km/h. No signs here: right before left! Give way to the right, then turn right." },
	{ x = 550, z = 40, t = "Signal left (Y) and turn into the driving school parking lot." },
	{ x = 550, z = 48, r = 16, t = "Park the car in any free parking bay and stop completely.", parken = true },
}

local function route(...)
	local liste = {}
	for _, teil in { ... } do
		for _, p in teil do table.insert(liste, p) end
	end
	return liste
end

local LEKTIONEN = {
	{
		titel = "Lesson 1: Basics & Turning",
		intro = "Hi, I'm Mike! W/S = gas and brake, A/D = steering. Indicators: Y = left, C = right, X = hazard lights. Drive through the green gates. 10 mistakes and the lesson does not count!",
		punkte = route(START, {
			{ x = 330, z = 0, t = "Country road: 100 km/h. Drive towards the city." },
			{ x = 208, z = 0, t = "City limit: 50 km/h! Turn right at the next intersection." },
			{ x = 208, z = -104, t = "STOP sign ahead: stop completely, then turn left." },
			{ x = 104, z = -104, t = "Traffic light ahead. Turn left here." },
			{ x = 104, z = 0, t = "Turn left and leave the city again." },
			{ x = 330, z = 0, t = "Well done. Back to the country road." },
		}, HEIMWEG),
	},
	{
		titel = "Lesson 2: Traffic Lights & Right of Way",
		intro = "Today we drive through the city centre. Watch the traffic lights: stop at red before the white stop line!",
		punkte = route(START, {
			{ x = 330, z = 0, t = "Drive into the city." },
			{ x = 104, z = 0, t = "Traffic light ahead. Go straight on green." },
			{ x = 0, z = 0, t = "Keep going straight." },
			{ x = -104, z = 0, t = "Turn right at this traffic light." },
			{ x = -104, z = -104, t = "Turn right again." },
			{ x = 0, z = -104, t = "Straight on." },
			{ x = 104, z = -104, t = "Turn right at the traffic light." },
			{ x = 104, z = 0, t = "Turn left towards the country road." },
			{ x = 330, z = 0, t = "Great driving! Head back to the school." },
		}, HEIMWEG),
	},
	{
		titel = "Lesson 3: Country Road & Highway",
		intro = "Today we go on the highway. Merge carefully, keep right and only overtake on the left.",
		punkte = route({
			{ x = 550, z = 40, t = "Drive out of the parking bay. Signal right (C) and turn right." },
			{ x = 700, z = 40, t = "Turn left at the next intersection." },
			{ x = 700, z = 0, t = "STOP sign at the exit: stop, then turn right towards the highway." },
			{ x = 780, z = 0, t = "Turn left onto the highway access road." },
			{ x = 780, z = -300, t = "Country road: 100 km/h." },
			{ x = 780, z = HZ, r = 18, t = "Turn left onto the highway. Speed limit 130 km/h." },
			{ x = 450, z = HZ - 10, r = 16, breite = 22, t = "Stay in the right lane." },
			{ x = 100, z = HZ - 10, r = 16, breite = 22, t = "Take the next exit on the left into the city." },
			{ x = 0, z = HZ, r = 18, t = "Exit the highway here." },
			{ x = 0, z = -330, t = "City limit: slow down to 50 km/h." },
			{ x = 0, z = 0, t = "Turn left at the traffic light." },
			{ x = 330, z = 0, t = "Drive back to the driving school." },
		}, HEIMWEG),
	},
	{
		titel = "Lesson 4: Roundabout",
		intro = "Today we drive through a roundabout. Traffic inside has priority, and you signal when you leave.",
		punkte = route(START, {
			{ x = 330, z = 0, t = "Drive into the city." },
			{ x = 0, z = 0, t = "Turn left at this traffic light." },
			{ x = 0, z = 330, t = "Leave the city towards the roundabout." },
			{ x = 0, z = 560, t = "Roundabout ahead! Give way to traffic inside, then take the third exit." },
			{ x = -24, z = 600, r = 12, t = "Keep driving around." },
			{ x = 0, z = 624, r = 12, t = "Next exit is yours." },
			{ x = 24, z = 600, r = 12, t = "Signal right and leave the roundabout." },
			{ x = 300, z = 600, t = "Country road: 100 km/h." },
			{ x = 756, z = 600, r = 12, t = "Roundabout! Give way to traffic inside, then take the 3rd exit (north)." },
			{ x = 780, z = 624, r = 12, t = "Keep going around." },
			{ x = 804, z = 600, r = 12, t = "Next exit is yours." },
			{ x = 780, z = 576, r = 12, t = "Signal right and leave the roundabout to the north." },
			{ x = 780, z = 276, t = "Turn left at the next junction." },
			{ x = 700, z = 276, t = "Turn right into the residential area. 30 km/h!" },
			{ x = 700, z = 40, t = "Watch the signs: STOP, YIELD, and right before left where there are none. Turn left at the last intersection." },
			{ x = 550, z = 40, t = "Signal left (Y) and turn into the driving school parking lot." },
			{ x = 550, z = 48, r = 16, t = "Park the car in any free parking bay and stop completely.", parken = true },
		}),
	},
	{
		titel = "Lesson 5: Parking",
		intro = "Last lesson: we drive one round through the neighbourhood, then you park in the marked bay.",
		punkte = {
			{ x = 550, z = 40, t = "Drive out of the parking bay. Signal right (C) and turn right." },
			{ x = 600, z = 40, t = "Turn right at the next intersection." },
			{ x = 600, z = 152, t = "Turn right." },
			{ x = 500, z = 152, t = "Turn right." },
			{ x = 500, z = 40, t = "Turn right towards the parking lot." },
			{ x = 522, z = 40, r = 16, t = "Now park in the highlighted bay (front left). Stop completely inside it.", parken = true, uebung = true },
		},
	},
}

-- Practical driving test: one of these routes is picked at random.
-- The examiner gives the directions (no hints about mistakes!).
local function pruefung(titel, mitte, anfang, ende)
	local punkte = route(anfang or START, mitte, ende or HEIMWEG)
	return { titel = titel, intro = "Good luck! I'm your examiner. Follow my directions and drive safely. You may make at most 3 mistakes.", punkte = punkte }
end
LEKTIONEN.PRUEFUNGEN = {
	pruefung("Driving test: City", {
		{ x = 330, z = 0, t = "Drive towards the city." },
		{ x = 104, z = 0, t = "Go straight at the traffic light." },
		{ x = 0, z = 0, t = "Turn right at the next traffic light." },
		{ x = 0, z = -104, t = "Turn right." },
		{ x = 104, z = -104, t = "Turn right again." },
		{ x = 104, z = 0, t = "Turn left towards the country road." },
		{ x = 330, z = 0, t = "Drive back to the driving school." },
	}),
	pruefung("Driving test: Highway", {
		{ x = 780, z = 0, t = "Turn left onto the access road." },
		{ x = 780, z = -300, t = "Country road, 100 km/h." },
		{ x = 780, z = -520, r = 18, t = "Turn left onto the highway." },
		{ x = 300, z = -530, r = 16, breite = 22, t = "Keep right." },
		{ x = 0, z = -520, r = 18, t = "Take the exit on the left into the city." },
		{ x = 0, z = -330, t = "City limit, 50 km/h." },
		{ x = 0, z = 0, t = "Turn left at the traffic light." },
		{ x = 330, z = 0, t = "Drive back to the driving school." },
	}, {
		{ x = 550, z = 40, t = "Drive out of the parking bay and turn right." },
		{ x = 700, z = 40, t = "Turn left at the next intersection." },
		{ x = 700, z = 0, t = "STOP sign: stop, then turn right towards the highway." },
	}),
	pruefung("Driving test: Roundabout", {
		{ x = 330, z = 0, t = "Drive into the city." },
		{ x = 0, z = 0, t = "Turn left at the traffic light." },
		{ x = 0, z = 330, t = "Leave the city towards the roundabout." },
		{ x = 0, z = 560, t = "In the roundabout, take the second exit." },
		{ x = -24, z = 600, r = 12, t = "Keep going." },
		{ x = 0, z = 624, r = 12, t = "Next exit is yours." },
		{ x = 24, z = 600, r = 12, t = "Signal right and leave the roundabout." },
		{ x = 756, z = 600, r = 12, t = "Roundabout! Give way to traffic inside, then take the 3rd exit (north)." },
			{ x = 780, z = 624, r = 12, t = "Keep going around." },
			{ x = 804, z = 600, r = 12, t = "Next exit is yours." },
			{ x = 780, z = 576, r = 12, t = "Signal right and leave the roundabout to the north." },
		{ x = 780, z = 276, t = "Turn left at the next junction." },
		{ x = 700, z = 276, t = "Turn right into the residential area. 30 km/h!" },
		{ x = 700, z = 40, t = "Turn left at the next intersection." },
	}, nil, {
		{ x = 550, z = 40, t = "Signal left and turn into the driving school parking lot." },
		{ x = 550, z = 48, r = 16, t = "Park the car in any free parking bay and stop completely.", parken = true },
	}),
}

-- Truck test (class C): starts and ends at the Parcel Express depot
LEKTIONEN.LKW = {
	titel = "Truck driving test (Class C)",
	intro = "Welcome to your truck test! A truck is long and heavy: brake early, and take corners slowly and wide. You may make at most 3 mistakes.",
	punkte = {
		{ x = 600, z = 340, r = 16, t = "Drive out of the bay and leave the depot to the north." },
		{ x = 600, z = 276, t = "Signal right (C) and turn right onto the ring road. 30 km/h!" },
		{ x = 780, z = 276, t = "Signal left (Y) and turn left at the junction." },
		{ x = 780, z = 0, t = "Turn left onto the country road. Take the corner wide!" },
		{ x = 420, z = 0, t = "Signal left and turn left at the next junction." },
		{ x = 420, z = 276, t = "Turn left onto the ring road." },
		{ x = 600, z = 276, t = "Signal right and turn back into the depot." },
		{ x = 600, z = 350, r = 20, t = "Park the truck in a free bay and stop completely.", parken = true, lkw = true },
	},
}

return LEKTIONEN

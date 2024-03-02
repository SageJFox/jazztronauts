// loaded by both loading and loading-basic
// no es6 in this file cause awesomium

var nextstop = {
	'en':    "Next Stop:",
	'en-PT': "Avast, ye be comin' up on:",
};

var thebar = {
	'en':    "The Bar",
	'en-PT': "Th' Tavern"
};


function GameDetails(_, _, mapname, _, _, _, _, lang) {
	switch (mapname) {
		case "jazz_bar":
		case "jazz_outro":
		case "jazz_outro2":
		case "jazz_apartments": //tee hee
			mapname = thebar[lang] || thebar['en'];
	}

	document.getElementById("nextstop").textContent = nextstop[lang] || nextstop['en'];
	document.getElementById("mapname").textContent = mapname;
}

var params = new URLSearchParams(window.location.search)
if (params.has('debug')) {
	var img = document.createElement("img")
	img.src = "images/startinglua.png"
	img.style = "position: absolute; bottom: 10px; right: 10px; z-index: 9999"
	document.body.appendChild(img)
}

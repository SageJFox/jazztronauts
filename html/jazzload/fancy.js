const trolleyZ = Number( window.getComputedStyle(document.getElementById("trolley")).getPropertyValue('z-index') )
const scrollers = document.getElementById("scrollers")

function makeScroller(className = "") {
	const tag = document.createElement("img");
	if (className) tag.className = className;
	scrollers.appendChild(tag);
	return tag;
}

function setScroller(tag, img = "", backimg = img) {
	// force a refresh so the animation will repeat
	tag.style = "";
	void tag.offsetWidth;

	// set the y position randomly, 60 seems to keep them near to the top
	let top = Math.random() * 80;
	tag.style.top = top + "%";

	// ensure that height and speed scale relative to one another
	const seed = Math.random();

	// set height
	let height = 20;
	height = height + (height * (seed - 0.5));
	tag.style.height = height + "%";

	// setting speed - smaller scrollers take longer (they're further away)
	let dur = 15;
	dur = dur * .2 + (dur * .8 * (1 - seed));
	tag.style.animationDuration = dur + "s";

	// a boost to the size/blur of those that are lower
	let boost = Math.max(0,(top-50)/100);

	// larger ones are closer, show back if in front of trolley
	tag.style.zIndex = Math.round(height * (1 + boost));
	let near = tag.style.zIndex >= trolleyZ
	tag.src = "images/" + (near ? backimg : img)

	// very close ones get blurry
	let blur = Math.floor(Math.abs(height - 20 + Math.max(0,tag.style.zIndex - trolleyZ))/10) + boost * 2;
	tag.style.filter = "blur(" + blur + "px)";

	tag.style.animationName = "scrollanim";
	return near;
}



// create permanent cats
for (let i = 0; i < 3; i++) {
	const cat = makeScroller();

	set =()=> setScroller(cat, "cat.png", "catback.png");
	set();

	// random start pos
	cat.style.animationDelay = Math.random() * -10 + "s";

	// when cat anim is done, set a different anim
	cat.addEventListener("animationend", set);
}


// relative to images/icons
const exts = {
	'png': "picture.png",
	'jpg': "picture.png",
	'jpeg':"picture.png",
	'vtf': "picture.png",
	'vmt': "page_white_picture.png",

	'wav': "sound.png",
	'mp3': "sound.png",
	'ogg': "sound.png",

	'txt': "page_white_text.png",
	'html':"page_white_world.png",

	'bsp': "world.png",
	'ain': "world_add.png",

	'ttf': "font.png",
	'otf': "font.png",

	'mdl': "brick.png",
	'vvd': "brick_add.png",
	'vtx': "brick_add.png",
	'phy': "brick_add.png",

	'db':  "database.png"
}

const anims = [
	["spinny", 6, "linear"],
	["bouncy", 4, "cubic-bezier(.45,.05,.55,.95)", "alternate"],
	["fly"],
]

function DownloadingFile( filename ) {
	const ext =  filename.split(".").pop();
	const icon = exts[ext] || "package.png";

	const img = makeScroller("crispy");
	const near = setScroller(img, "icons/" + icon)

	const anim = anims[Math.floor(Math.random() * anims.length)]

	let animname = anim[0]
	if (animname == "fly") {
		animname = near ? "flyin" : "flyout"
	}

	// unfortunate string concatenation disaster to allow multiple animations
	img.style.animationName += ", " + animname
	if (anim[1]) img.style.animationDuration += ", " + anim[1] * Math.random() + "s"
	if (anim[2]) img.style.animationTimingFunction = "linear, " + anim[2]
	if (anim[3]) img.style.animationDirection = anim[3]

	// remove it once it goes offscreen
	img.addEventListener("animationend", function (anim) {
		if (anim == "scrollanim") img.remove()
	});
}

const trolleyZ = Number(window.getComputedStyle(document.getElementById("trolley")).getPropertyValue('z-index'))
const scrollers = document.getElementById("scrollers")

function makeScroller(src, className = "") {
	const tag = document.createElement("img");
	tag.src = `images/${src}`;
	if (className) tag.classList.add(className); // "scroller-" + src.split(".")[0]
	scrollers.appendChild(tag);
	return tag;
}

function setScroller(tag, img = "", backimg = "") {
	// force a refresh so the animation will repeat
	tag.style = ""
	void tag.offsetWidth;
	
	let top = Math.random() * 80;

	// set the y position randomly, 60 seems to keep them closer to the top
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

	//a boost to the size/blur of those that are lower
	let boost = Math.max(0,(top-50)/100);
	// larger ones are closer, show back if in front of trolley
	tag.style.zIndex = Math.round(height * (1 + boost));
	if (img && backimg) {
		if (tag.style.zIndex >= trolleyZ) {
			tag.src = `images/${backimg}`
		} else {
			tag.src = `images/${img}`
		}
	}
	let blur = Math.floor(Math.abs(height - 20 + Math.max(0,tag.style.zIndex - trolleyZ))/10) + boost * 2;
	//console.log(blur);
	tag.style.filter = "blur(" + blur + "px)";
	tag.style.animationName = "scrollanim";
}



// create permanent cats
for (let i = 0; i < 3; i++) {
	const cat = makeScroller("cat.png")

	set =()=> setScroller(cat, "cat.png", "catback.png");
	set();

	// random start pos
	cat.style.animationDelay = Math.random() * -10 + "s";

	// when cat anim is done, set a different anim
	cat.addEventListener("animationend", set);
}



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
	'html': "page_white_world.png",

	'bsp': "world.png",
	'ain': "world_add.png",

	'ttf': "font.png",
	'otf': "font.png",

	'mdl': "brick.png",
	'vvd': "brick_add.png",
	'vtx': "brick_add.png",
	'phy': "brick_add.png",

	'db': "database.png"
}

const anims = [
	["spinny", 6, "linear"],
	["bouncy", 4, "cubic-bezier(.45,.05,.55,.95)", "alternate"],
	["fly"],
]

function DownloadingFile( filename ) {
	const ext =  filename.split(".").pop();
	const icon = exts[ext] || "package.png";

	const img = makeScroller(icon, "scroller-asset");
	setScroller(img)

	const animation = anims[Math.floor(Math.random() * anims.length)]

	let animname = animation[0]
	if (animname == "fly") {
		if (img.style.zIndex >= trolleyZ) {
			animname = "flyin"
		} else {
			animname = "flyout"
		}
	}

	// unfortunate string concatenation disaster to allow multiple animations
	img.style.animationName += `, ${animname}`
	img.style.animationIterationCount = "1, infinite"
	if (animation[1]) img.style.animationDuration += `, ${Math.random() * animation[1]}s`
	if (animation[2]) img.style.animationTimingFunction = "linear, " + animation[2]
	if (animation[3]) img.style.animationDirection = animation[3]

	img.addEventListener("animationend", (anim)=>{
		if (anim == "scrollanim") img.remove()
	});
}

// Reference frame sheets for emote research (run in the built-in browser on a page with a <video>, e.g. a
// YouTube watch page): pauses the video, seeks to each time and draws that frame into a grid laid over the
// page, labelled with its time. The grid is only looked at (screenshots/zoom); nothing is saved or exported.
//
//   await window.__refsheet([63.4, 63.6, 63.8, ...], { cols: 4, mirror: false, crop: [x0, y0, x1, y1] })
//   window.__refsheetHide()
//
// crop is a fraction of the video frame (0..1) to blow up one dancer; mirror flips tutorials filmed facing
// the camera so left/right read as the dancer's own.
window.__refsheet = async function (times, opts) {
	opts = opts || {};
	const v = document.querySelector("video");
	v.pause();
	v.muted = true;
	const cols = opts.cols || 4;
	const rows = Math.ceil(times.length / cols);
	const crop = opts.crop || [0, 0, 1, 1];
	const sw = v.videoWidth * (crop[2] - crop[0]);
	const sh = v.videoHeight * (crop[3] - crop[1]);
	const W = window.innerWidth;
	const H = window.innerHeight;
	let cw = Math.floor(W / cols);
	let ch = Math.floor((cw * sh) / sw);
	if (ch * rows > H) {
		ch = Math.floor(H / rows);
		cw = Math.floor((ch * sw) / sh);
	}
	let c = document.getElementById("__refsheet");
	if (!c) {
		c = document.createElement("canvas");
		c.id = "__refsheet";
		document.body.appendChild(c);
	}
	c.width = cw * cols;
	c.height = ch * rows;
	Object.assign(c.style, {
		position: "fixed", left: "0px", top: "0px", zIndex: 2147483647,
		width: c.width + "px", height: c.height + "px", background: "#000",
	});
	const g = c.getContext("2d");
	g.fillStyle = "#000";
	g.fillRect(0, 0, c.width, c.height);
	for (let i = 0; i < times.length; i++) {
		await new Promise((resolve) => {
			const done = () => {
				v.removeEventListener("seeked", done);
				resolve();
			};
			v.addEventListener("seeked", done);
			v.currentTime = times[i];
		});
		await new Promise((r) => setTimeout(r, opts.settle || 150));
		const x = (i % cols) * cw;
		const y = Math.floor(i / cols) * ch;
		g.save();
		if (opts.mirror) {
			g.translate(x + cw, y);
			g.scale(-1, 1);
			g.drawImage(v, crop[0] * v.videoWidth, crop[1] * v.videoHeight, sw, sh, 0, 0, cw, ch);
		} else {
			g.drawImage(v, crop[0] * v.videoWidth, crop[1] * v.videoHeight, sw, sh, x, y, cw, ch);
		}
		g.restore();
		g.strokeStyle = "#444";
		g.strokeRect(x + 0.5, y + 0.5, cw - 1, ch - 1);
		g.fillStyle = "rgba(0,0,0,0.65)";
		g.fillRect(x, y, 64, 16);
		g.fillStyle = "#fff";
		g.font = "12px monospace";
		g.fillText(times[i].toFixed(2), x + 4, y + 12);
	}
	return { cw: cw, ch: ch, rows: rows, video: [v.videoWidth, v.videoHeight], duration: v.duration };
};
window.__refsheetHide = function () {
	const c = document.getElementById("__refsheet");
	if (c) {
		c.remove();
	}
};

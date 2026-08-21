(() => {
	const action = new PlugIn.Action(async function () {
		const lib = this.plugIn.library("tempusLib");
		try {
			const cfg = await lib.requireConfig();
			const cur = await lib.stopCurrent(cfg);
			if (cur) {
				const secs = Math.max(0, Math.round((Date.now() - new Date(cur.start).getTime()) / 1000));
				await new Alert("⏹ Tempus", cur.description + " — " + lib.fmt(secs)).show();
			} else {
				await new Alert("Tempus", "Aucun compteur en cours.").show();
			}
		} catch (err) {
			new Alert("Tempus — erreur", String((err && err.message) || err)).show();
		}
	});

	action.validate = function () { return true; };

	return action;
})();

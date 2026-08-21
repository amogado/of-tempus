(() => {
	const action = new PlugIn.Action(async function () {
		const lib = this.plugIn.library("tempusLib");
		try {
			await lib.configure();
			const cfg = lib.getConfig();
			if (cfg.base && cfg.token) {
				await lib.api(cfg, "GET", "/me");
				await new Alert("Tempus", "✅ Connexion OK (" + cfg.workspace + ")").show();
			}
		} catch (err) {
			new Alert("Tempus — erreur", String((err && err.message) || err)).show();
		}
	});

	action.validate = function () { return true; };

	return action;
})();

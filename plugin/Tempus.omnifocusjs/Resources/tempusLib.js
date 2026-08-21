(() => {
	const lib = new PlugIn.Library(new Version("0.3"));
	const prefs = new Preferences("com.amogado.of-tempus");

	// Token in Preferences: Credentials proved unreliable across launches on iOS.
	// Preferences live inside OmniFocus's sandbox and persist on both platforms.
	lib.getConfig = () => ({
		base: prefs.readString("baseURL") || "",
		workspace: prefs.readString("workspace") || "",
		token: prefs.readString("token") || ""
	});

	lib.configure = async () => {
		const cfg = lib.getConfig();
		const form = new Form();
		form.addField(new Form.Field.String("base", "URL Tempus", cfg.base || "https://"));
		form.addField(new Form.Field.String("workspace", "Workspace", cfg.workspace || "My Workspace"));
		form.addField(new Form.Field.String("token", "Token API (vide = inchangé)", ""));
		await form.show("Configuration Tempus", "Enregistrer");
		prefs.write("baseURL", String(form.values.base || "").replace(/\/+$/, ""));
		prefs.write("workspace", String(form.values.workspace || ""));
		if (form.values.token) { prefs.write("token", String(form.values.token)); }
	};

	lib.requireConfig = async () => {
		let cfg = lib.getConfig();
		if (!cfg.base || !cfg.token) {
			await lib.configure();
			cfg = lib.getConfig();
			if (!cfg.base || !cfg.token) { throw new Error("Configuration incomplète."); }
		}
		return cfg;
	};

	lib.api = async (cfg, method, path, body) => {
		const req = URL.FetchRequest.fromString(cfg.base + "/api/v9" + path);
		req.method = method;
		req.headers = { "Authorization": "Bearer " + cfg.token, "Content-Type": "application/json" };
		if (body) { req.bodyString = JSON.stringify(body); }
		const resp = await req.fetch();
		if (resp.statusCode === 401) { throw new Error("Token refusé (401). Lance « Tempus: Configure »."); }
		if (resp.statusCode >= 300) { throw new Error("Tempus HTTP " + resp.statusCode + " (" + method + " " + path + ")"); }
		const txt = resp.bodyString;
		return txt ? JSON.parse(txt) : null;
	};

	lib.getWid = async (cfg) => {
		const wss = await lib.api(cfg, "GET", "/workspaces");
		if (!wss || wss.length === 0) { throw new Error("Aucun workspace Tempus."); }
		const ws = wss.find(w => w.name === cfg.workspace) || wss[0];
		return ws.id;
	};

	lib.ensureProject = async (cfg, wid, clientName, projectName) => {
		let cid = null;
		if (clientName) {
			const clients = (await lib.api(cfg, "GET", "/workspaces/" + wid + "/clients")) || [];
			const c = clients.find(x => x.name === clientName);
			if (c) {
				cid = c.id;
			} else {
				// Client creation lives on Tempus's admin surface (/api), not the
				// Toggl v9 one; tolerate failure and fall back to a client-less project.
				try {
					cid = (await lib.api(cfg, "POST", "/workspaces/" + wid + "/clients", { name: clientName })).id;
				} catch (e) { cid = null; }
			}
		}
		const projects = (await lib.api(cfg, "GET", "/workspaces/" + wid + "/projects")) || [];
		const p = projects.find(x => x.name === projectName && (!cid || x.client_id === cid)) ||
			projects.find(x => x.name === projectName);
		if (p) { return p.id; }
		const body = { name: projectName, active: true };
		if (cid) { body.client_id = cid; }
		return (await lib.api(cfg, "POST", "/workspaces/" + wid + "/projects", body)).id;
	};

	lib.stopCurrent = async (cfg) => {
		const cur = await lib.api(cfg, "GET", "/me/time_entries/current");
		if (!cur) { return null; }
		const wid = cur.workspace_id || (await lib.getWid(cfg));
		await lib.api(cfg, "PATCH", "/workspaces/" + wid + "/time_entries/" + cur.id + "/stop");
		return cur;
	};

	lib.fmt = (secs) => {
		const h = Math.floor(secs / 3600), m = Math.floor((secs % 3600) / 60), s = secs % 60;
		return h > 0 ? h + "h" + String(m).padStart(2, "0") : (m > 0 ? m + "m" + String(s).padStart(2, "0") : s + "s");
	};

	return lib;
})();

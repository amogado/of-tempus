(() => {
	const action = new PlugIn.Action(async function (selection) {
		const lib = this.plugIn.library("tempusLib");
		try {
			const task = selection.tasks[0];
			if (!task) { throw new Error("Sélectionne une tâche."); }
			const cfg = await lib.requireConfig();

			await lib.stopCurrent(cfg);

			const wid = await lib.getWid(cfg);
			const project = task.containingProject;
			const clientName = project && project.parentFolder ? project.parentFolder.name : "";
			const projectName = project ? project.name : "Inbox";
			const pid = await lib.ensureProject(cfg, wid, clientName, projectName);
			const body = {
				description: task.name,
				workspace_id: wid,
				duration: -1,
				start: new Date().toISOString(),
				created_with: "of-tempus-plugin"
			};
			if (pid) { body.project_id = pid; }
			await lib.api(cfg, "POST", "/workspaces/" + wid + "/time_entries", body);
			await new Alert("▶️ Tempus", "[" + (clientName || "—") + " / " + projectName + "] " + task.name).show();
		} catch (err) {
			new Alert("Tempus — erreur", String((err && err.message) || err)).show();
		}
	});

	action.validate = function (selection) {
		return selection && selection.tasks && selection.tasks.length === 1;
	};

	return action;
})();

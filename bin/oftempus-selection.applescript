-- oftempus-selection — report the currently selected OmniFocus task.
-- Prints JSON: {"id":..., "name":..., "project":..., "client":...}
-- or "NONE" when no task is selected / OmniFocus isn't running.
-- client = nearest enclosing folder of the task's project.

on run
	tell application "System Events"
		if not (exists process "OmniFocus") then return "NONE"
	end tell
	tell application "OmniFocus"
		set js to "
			(() => {
				const wins = document.windows;
				if (wins.length === 0) { return 'NONE'; }
				const sel = wins[0].selection;
				const tasks = sel.tasks || [];
				if (tasks.length === 0) { return 'NONE'; }
				const t = tasks[0];
				const p = t.containingProject;
				const folder = p && p.parentFolder ? p.parentFolder.name : '';
				return JSON.stringify({
					id: t.id.primaryKey,
					name: t.name,
					project: p ? p.name : 'Inbox',
					client: folder
				});
			})()
		"
		try
			return evaluate javascript js
		on error
			return "NONE"
		end try
	end tell
end run

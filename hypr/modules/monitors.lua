hl.monitor({
    output   = "",
    mode     = "preffered",
    position = "auto",
    scale    = "1.6",
})

--workspaces 1-5 on main monitor
hl.workspace_rule({ workspace = "1", monitor = "EDP-1", persistent = true })
hl.workspace_rule({ workspace = "2", monitor = "EDP-1", persistent = true })
hl.workspace_rule({ workspace = "3", monitor = "EDP-1", persistent = true })
hl.workspace_rule({ workspace = "4", monitor = "EDP-1", persistent = true })
hl.workspace_rule({ workspace = "5", monitor = "EDP-1", persistent = true })


#pragma once

#include <stddef.h>

#include "yaml.h"

typedef struct {
	const char *service_name;
	const char *pane_id;
} ServicePane;

typedef struct {
	const char *session_name;
	const char *compose_file;
	ServicePane *panes;
	size_t count;
} TmuxPanes;

int tmux_attach_container_by_name(TmuxPanes *tmux_panes, const char *service_name);
int tmux_detach_container_by_name(TmuxPanes *tmux_panes, const char *service_name);

int tmux_attach_compose_services(TmuxPanes *tmux_panes, const ComposeServices *services);
int tmux_detach_compose_services(TmuxPanes *tmux_panes, const ComposeServices *services);

int tmux_panes_init(TmuxPanes *tmux_panes, const char *compose_file);
void tmux_panes_destroy(TmuxPanes *tmux_panes);

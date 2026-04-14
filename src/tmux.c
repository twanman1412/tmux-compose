#include "tmux.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *dup_string(const char *s) {
	size_t len;
	char *copy;

	if (s == NULL) {
		return NULL;
	}

	len = strlen(s);
	copy = malloc(len + 1U);
	if (copy == NULL) {
		return NULL;
	}

	memcpy(copy, s, len + 1U);
	return copy;
}

static int find_service_index(const TmuxPanes *tmux_panes, const char *service_name) {
	if (tmux_panes == NULL || service_name == NULL) {
		return -1;
	}

	for (size_t i = 0; i < tmux_panes->count; i++) {
		if (tmux_panes->panes[i].service_name != NULL &&
				strcmp(tmux_panes->panes[i].service_name, service_name) == 0) {
			return (int)i;
		}
	}

	return -1;
}

static int append_service_pane(TmuxPanes *tmux_panes, const char *service_name, const char *window_target) {
	ServicePane *new_items;
	char *service_copy;
	char *target_copy;

	if (tmux_panes == NULL || service_name == NULL || window_target == NULL) {
		return -1;
	}

	new_items = realloc(tmux_panes->panes, (tmux_panes->count + 1U) * sizeof(ServicePane));
	if (new_items == NULL) {
		return -1;
	}

	service_copy = dup_string(service_name);
	if (service_copy == NULL) {
		return -1;
	}

	target_copy = dup_string(window_target);
	if (target_copy == NULL) {
		free(service_copy);
		return -1;
	}

	tmux_panes->panes = new_items;
	tmux_panes->panes[tmux_panes->count].service_name = service_copy;
	tmux_panes->panes[tmux_panes->count].pane_id = target_copy;
	tmux_panes->count++;

	return 0;
}

int tmux_attach_container_by_name(TmuxPanes *tmux_panes, const char *service_name) {
	char command[1024];
	char rollback_command[384];
	char window_target[384];

	if (tmux_panes == NULL || service_name == NULL || tmux_panes->session_name == NULL) {
		fprintf(stderr, "Invalid state to tmux_attach_container_by_name\n");
		return -1;
	}

	if (find_service_index(tmux_panes, service_name) >= 0) {
		// Already attached to this service, do nothing
		return 0;
	}


	if (snprintf(command,
				sizeof(command),
				"tmux new-window -t \"%s\" -n \"%s\" \"docker-compose -f %s logs -f %s\"",
				tmux_panes->session_name,
				service_name,
				tmux_panes->compose_file,
				service_name) >= (int)sizeof(command)) {
		fprintf(stderr, "Failed to construct tmux command for service '%s'\n", service_name);
		return -1;
	}

	if (system(command) != 0) {
		fprintf(stderr, "Failed to execute tmux command: %s\n", command);
		return -1;
	}

	if (snprintf(window_target, sizeof(window_target), "%s:%s", tmux_panes->session_name, service_name) >=
			(int)sizeof(window_target)) {
		fprintf(stderr, "Failed to construct window target for service '%s'\n", service_name);
		return -1;
	}

	if (append_service_pane(tmux_panes, service_name, window_target) != 0) {
		fprintf(stderr, "Failed to record attached service '%s' in internal state\n", service_name);
		if (snprintf(rollback_command, sizeof(rollback_command), "tmux kill-window -t \"%s\"", window_target) <
				(int)sizeof(rollback_command)) {
			(void)system(rollback_command);
		}
		return -1;
	}

	return 0;
}

int tmux_detach_container_by_name(TmuxPanes *tmux_panes, const char *service_name) {
	int index;
	char command[384];
	const char *window_target;
	size_t session_name_len;

	if (tmux_panes == NULL || service_name == NULL || tmux_panes->session_name == NULL){
		fprintf(stderr, "Invalid state to tmux_detach_container_by_name\n"); 
		return -1;
	}

	index = find_service_index(tmux_panes, service_name);
	if (index < 0) {
		return 0;
	}

	window_target = tmux_panes->panes[index].pane_id;
	if (window_target == NULL || window_target[0] == '\0') {
		return -1;
	}

	session_name_len = strlen(tmux_panes->session_name);
	if (strncmp(window_target, tmux_panes->session_name, session_name_len) != 0 ||
			window_target[session_name_len] != ':') {
		return -1;
	}

	if (snprintf(command, sizeof(command), "tmux kill-window -t \"%s\"", window_target) >= (int)sizeof(command)) {
		return -1;
	}

	if (system(command) != 0) {
		return -1;
	}

	free((void *)tmux_panes->panes[index].service_name);
	free((void *)tmux_panes->panes[index].pane_id);

	for (size_t i = (size_t)index; i + 1U < tmux_panes->count; i++) {
		tmux_panes->panes[i] = tmux_panes->panes[i + 1U];
	}
	tmux_panes->count--;

	if (tmux_panes->count == 0U) {
		free(tmux_panes->panes);
		tmux_panes->panes = NULL;
	} else {
		ServicePane *shrunk = realloc(tmux_panes->panes, tmux_panes->count * sizeof(ServicePane));
		if (shrunk != NULL) {
			tmux_panes->panes = shrunk;
		}
	}

	return 0;
}

int tmux_attach_compose_services(TmuxPanes *tmux_panes, const ComposeServices *services) {
	if (tmux_panes == NULL || services == NULL) {
		return -1;
	}

	for (size_t i = 0; i < services->count; i++) {
		const char *service_name = compose_services_get(services, i);
		if (service_name == NULL) {
			continue;
		}
		if (tmux_attach_container_by_name(tmux_panes, service_name) != 0) {
			return -1;
		}
	}

	return 0;
}

int tmux_detach_compose_services(TmuxPanes *tmux_panes, const ComposeServices *services) {
	if (tmux_panes == NULL || services == NULL) {
		return -1;
	}

	for (size_t i = 0; i < services->count; i++) {
		const char *service_name = compose_services_get(services, i);
		if (service_name == NULL) {
			continue;
		}
		if (tmux_detach_container_by_name(tmux_panes, service_name) != 0) {
			return -1;
		}
	}

	return 0;
}

int tmux_panes_init(TmuxPanes *tmux_panes, const char *compose_file) {
	char session_name_buffer[256];
	char command[640];
	const char *cwd;

	if (tmux_panes == NULL) {
		fprintf(stderr, "tmux_panes_init: tmux_panes is NULL\n");
		return -1;
	}

	tmux_panes->panes = NULL;
	tmux_panes->count = 0U;
	tmux_panes->session_name = NULL;
	tmux_panes->compose_file = compose_file;

	cwd = getenv("PWD");
	if (cwd == NULL || cwd[0] == '\0') {
		cwd = ".";
	}

	if (snprintf(session_name_buffer, sizeof(session_name_buffer), "tmux-compose_%s", cwd) >=
			(int)sizeof(session_name_buffer)) {
		fprintf(stderr, "tmux_panes_init: session name too long\n");
		return -1;
	}

	tmux_panes->session_name = dup_string(session_name_buffer);
	if (tmux_panes->session_name == NULL) {
		fprintf(stderr, "tmux_panes_init: failed to allocate session_name\n");
		return -1;
	}

	if (snprintf(command,
				sizeof(command),
				"tmux new-session -d -s \"%s\"",
				tmux_panes->session_name
				) >= (int)sizeof(command)) {
		fprintf(stderr, "tmux_panes_init: tmux command too long\n");
		free((void *)tmux_panes->session_name);
		tmux_panes->session_name = NULL;
		return -1;
	}

	if (system(command) != 0) {
		fprintf(stderr, "tmux_panes_init: failed to create or attach tmux session with command: %s\n", command);
		free((void *)tmux_panes->session_name);
		tmux_panes->session_name = NULL;
		return -1;
	}

	return 0;
}

void tmux_panes_destroy(TmuxPanes *tmux_panes) {
	if (tmux_panes == NULL) {
		return;
	}

	for (size_t i = 0; i < tmux_panes->count; i++) {
		free((void *)tmux_panes->panes[i].service_name);
		free((void *)tmux_panes->panes[i].pane_id);
	}

	free(tmux_panes->panes);
	tmux_panes->panes = NULL;
	tmux_panes->count = 0U;

	free((void *)tmux_panes->session_name);
	tmux_panes->session_name = NULL;
}

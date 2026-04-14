#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "yaml.h"
#include "tmux.h"

const char* find_compose_file(int argc, char *argv[]);

int main(int argc, char *argv[]) {
	char *compose_file = NULL;
	if (argc < 2) {
		if (access("docker-compose.yml", F_OK) != 0) {
			fprintf(stderr, "Failed to find a compose file'. Make sure you are in a directory with a docker-compose.yml file or provide the compose file path with -f.\n");
			return 1;
		}

		if (system("docker-compose ps --services --status running | grep -q . || exit 1") != 0) {
			fprintf(stderr, "No running containers found, and no commands provided. Please start your services with 'tmux-compose up' or provide the compose file path with -f.\n");
			return 1;
				}

		// no arguments, just attach to the current compose file
		compose_file = "docker-compose.yml";
	} else {
		char command[4096];
		int command_len = snprintf(command, sizeof(command), "docker-compose");
		if (command_len < 0 || (size_t)command_len >= sizeof(command)) {
			fprintf(stderr, "Failed to build docker-compose command\n");
			return 1;
		}

		for (int i = 1; i < argc; i++) {
			int written = snprintf(
					command + command_len,
					sizeof(command) - (size_t)command_len,
					" %s",
					argv[i]
					);
			if (written < 0 || (size_t)written >= sizeof(command) - (size_t)command_len) {
				fprintf(stderr, "docker-compose command is too long\n");
				return 1;
			}
			command_len += written;
		}

		int written = snprintf(
				command + command_len,
				sizeof(command) - (size_t)command_len,
				" -d"
				);
		if (written < 0 || (size_t)written >= sizeof(command) - (size_t)command_len) {
			fprintf(stderr, "docker-compose command is too long\n");
			return 1;
		}

		int system_result = system(command);
		if (system_result == -1) {
			perror("system");
			return 1;
		}
		if (system_result != 0) {
			fprintf(stderr, "docker-compose failed with exit code %d\n", system_result);
			return 1;
		}

		compose_file = (char*) find_compose_file(argc, argv);
	}

	if (access(compose_file, F_OK) != 0) {
		fprintf(stderr, "Compose file '%s' does not exist.\n", compose_file);
		return 1;
	}

	ComposeParser parser;
	ComposeServices services;

	compose_services_init(&services);
	compose_parser_init(&parser, compose_file);

	if (compose_parser_parse(&parser, &services) != 0) {
		fprintf(stderr, "Failed to parse compose file\n");
		compose_parser_destroy(&parser);
		compose_services_destroy(&services);
		return 1;
	}

	compose_parser_destroy(&parser);

	TmuxPanes tmux_panes;
	if (tmux_panes_init(&tmux_panes, compose_file) != 0) {
		fprintf(stderr, "Failed to initialize tmux session.\n");
		compose_services_destroy(&services);
		return 1;
	}

	if (tmux_attach_compose_services(&tmux_panes, &services) != 0) {
		fprintf(stderr, "Failed to create tmux windows for services.\n");
		tmux_panes_destroy(&tmux_panes);
		compose_services_destroy(&services);
		return 1;
	}

	char tmux_kill_empty_command[512];
	int tmux_kill_empty_command_len = snprintf(
			tmux_kill_empty_command,
			sizeof(tmux_kill_empty_command),
			"tmux kill-window -t %s:0",
			tmux_panes.session_name
			);
	if (tmux_kill_empty_command_len < 0 ||
			(size_t)tmux_kill_empty_command_len >= sizeof(tmux_kill_empty_command)) {
		fprintf(stderr, "Failed to build tmux kill-window command.\n");
		tmux_panes_destroy(&tmux_panes);
		compose_services_destroy(&services);
		return 1;
	}

	if (system(tmux_kill_empty_command) != 0) {
		fprintf(stderr, "Failed to kill default tmux window: %s:0\n", tmux_panes.session_name);
		tmux_panes_destroy(&tmux_panes);
		compose_services_destroy(&services);
		return 1;
	}

	execvp("tmux", (char *[]){"tmux", "attach-session","-t", (char*) tmux_panes.session_name, NULL});
	perror("execvp tmux");
	tmux_panes_destroy(&tmux_panes);
	compose_services_destroy(&services);
	return 1;
}

const char *find_compose_file(int argc, char *argv[]) {
	const char* compose_file = "docker-compose.yml";

	for (int i = 1; i < argc; i++) {
		const char *arg = argv[i];

		if (arg[0] == '-' && arg[1] == 'f' && arg[2] == '\0' && i + 1 < argc) {
			compose_file = argv[i + 1];
			i++;
			continue;
		}

		if (arg[0] == '-' && arg[1] == 'f' && arg[2] != '\0') {
			compose_file = &arg[2];
			continue;
		}

		if (arg[0] == '-' && arg[1] == '-' && arg[2] == 'f' && arg[3] == 'i' &&
				arg[4] == 'l' && arg[5] == 'e') {
			if (arg[6] == '=' && arg[7] != '\0') {
				compose_file = &arg[7];
				continue;
			}

			if (arg[6] == '\0' && i + 1 < argc) {
				compose_file = argv[i + 1];
				i++;
			}
		}
	}

	return compose_file;
}

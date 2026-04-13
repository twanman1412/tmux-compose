#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "yaml.h"

const char* find_compose_file(int argc, char *argv[]);

int main(int argc, char *argv[]) {
	char *compose_file = NULL;
	if (argc < 2) {
		// no arguments, just attach to the current compose file
		compose_file = "docker-compose.yml";
	} else {
		char **cmd = malloc((size_t)(argc + 2) * sizeof(char *));
		if (cmd == NULL) {
			perror("malloc");
			return 1;
		}

		cmd[0] = "docker-compose";
		for (int i = 1; i < argc; i++) {
			cmd[i] = argv[i];
		}
		cmd[argc] = "-d";
		cmd[argc + 1] = NULL;

		execvp(cmd[0], cmd);
		perror("execvp");
		free(cmd);

    	compose_file = (char*) find_compose_file(argc, argv);
	}

	fprintf(stdout, "Using compose file: %s\n", compose_file);

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

	for (size_t i = 0; i < services.count; i++) {
		const char *name = compose_services_get(&services, i);
		if (name != NULL) {
			fprintf(stdout, "Found service: %s\n", name);
		}
	}

    compose_parser_destroy(&parser);
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


#pragma once

#include <stddef.h>

typedef struct {
    char **container_names;
    size_t count;
} ComposeServices;

typedef struct {
    const char *file_path;
    char *buffer;
    size_t buffer_size;
} ComposeParser;

void compose_parser_init(ComposeParser *parser, const char *file_path);
void compose_parser_destroy(ComposeParser *parser);

int compose_parser_parse(ComposeParser *parser, ComposeServices *services);

void compose_services_init(ComposeServices *services);
void compose_services_destroy(ComposeServices *services);

const char *compose_services_get(const ComposeServices *services, size_t index);

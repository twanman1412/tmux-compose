#include "yaml.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int append_service(ComposeServices *services, const char *name, size_t name_len) {
    char **new_items;
    char *copy;

    new_items = realloc(services->container_names, (services->count + 1U) * sizeof(char *));
    if (new_items == NULL) {
        return -1;
    }

    copy = malloc(name_len + 1U);
    if (copy == NULL) {
        return -1;
    }

    memcpy(copy, name, name_len);
    copy[name_len] = '\0';

    services->container_names = new_items;
    services->container_names[services->count] = copy;
    services->count++;

    return 0;
}

static int parse_mapping_key(const char *line, size_t len, const char **key_start, size_t *key_len) {
    const char *colon;
    size_t trimmed_len;

    if (len == 0U || line[0] == '-' || line[0] == '#') {
        return 0;
    }

    colon = memchr(line, ':', len);
    if (colon == NULL) {
        return 0;
    }

    trimmed_len = (size_t)(colon - line);
    while (trimmed_len > 0U && isspace((unsigned char)line[trimmed_len - 1U])) {
        trimmed_len--;
    }
    if (trimmed_len == 0U) {
        return 0;
    }

    if ((line[0] == '"' || line[0] == '\'') && trimmed_len >= 2U && line[trimmed_len - 1U] == line[0]) {
        *key_start = line + 1;
        *key_len = trimmed_len - 2U;
        return *key_len > 0U;
    }

    *key_start = line;
    *key_len = trimmed_len;
    return 1;
}

void compose_parser_init(ComposeParser *parser, const char *file_path) {
    FILE *fp;
    long file_len;
    size_t bytes_read;

    if (parser == NULL) {
        return;
    }

    parser->file_path = file_path;
    parser->buffer = NULL;
    parser->buffer_size = 0U;

    if (file_path == NULL) {
        return;
    }

    fp = fopen(file_path, "rb");
    if (fp == NULL) {
        return;
    }

    if (fseek(fp, 0L, SEEK_END) != 0) {
        fclose(fp);
        return;
    }

    file_len = ftell(fp);
    if (file_len < 0) {
        fclose(fp);
        return;
    }

    if (fseek(fp, 0L, SEEK_SET) != 0) {
        fclose(fp);
        return;
    }

    parser->buffer = malloc((size_t)file_len + 1U);
    if (parser->buffer == NULL) {
        fclose(fp);
        return;
    }

    bytes_read = fread(parser->buffer, 1U, (size_t)file_len, fp);
    fclose(fp);

    parser->buffer[bytes_read] = '\0';
    parser->buffer_size = bytes_read;
}

void compose_parser_destroy(ComposeParser *parser) {
    if (parser == NULL) {
        return;
    }

    free(parser->buffer);
    parser->buffer = NULL;
    parser->buffer_size = 0U;
}

void compose_services_init(ComposeServices *services) {
    if (services == NULL) {
        return;
    }

    services->container_names = NULL;
    services->count = 0U;
}

void compose_services_destroy(ComposeServices *services) {
    if (services == NULL) {
        return;
    }

    for (size_t i = 0; i < services->count; i++) {
        free(services->container_names[i]);
    }
    free(services->container_names);

    services->container_names = NULL;
    services->count = 0U;
}

const char *compose_services_get(const ComposeServices *services, size_t index) {
    if (services == NULL || index >= services->count) {
        return NULL;
    }

    return services->container_names[index];
}

int compose_parser_parse(ComposeParser *parser, ComposeServices *services) {
    char *line;
    int in_services;
    size_t services_indent;
    size_t service_key_indent;

    if (parser == NULL || services == NULL || parser->file_path == NULL || parser->buffer == NULL) {
        return -1;
    }

    compose_services_destroy(services);
    compose_services_init(services);

    in_services = 0;
    services_indent = 0U;
    service_key_indent = (size_t)-1;

    line = parser->buffer;
    while (*line != '\0') {
        char *line_end = strchr(line, '\n');
        size_t len;
        size_t indent = 0U;
        const char *key_start;
        size_t key_len;

        if (line_end != NULL) {
            len = (size_t)(line_end - line);
        } else {
            len = strlen(line);
        }

        if (len > 0U && line[len - 1U] == '\r') {
            len--;
        }

        while (indent < len && (line[indent] == ' ' || line[indent] == '\t')) {
            indent++;
        }

        if (indent >= len || line[indent] == '#') {
            if (line_end == NULL) {
                break;
            }
            line = line_end + 1;
            continue;
        }

        if (!in_services) {
            if (parse_mapping_key(line + indent, len - indent, &key_start, &key_len) != 0 &&
                key_len == 8U && strncmp(key_start, "services", 8U) == 0) {
                in_services = 1;
                services_indent = indent;
                service_key_indent = (size_t)-1;
            }
        } else {
            if (indent <= services_indent) {
                break;
            }

            if (parse_mapping_key(line + indent, len - indent, &key_start, &key_len) != 0) {
                if (service_key_indent == (size_t)-1) {
                    service_key_indent = indent;
                }
                if (indent == service_key_indent && key_len > 0U) {
                    if (append_service(services, key_start, key_len) != 0) {
                        return -1;
                    }
                }
            }
        }

        if (line_end == NULL) {
            break;
        }
        line = line_end + 1;
    }

    return 0;
}

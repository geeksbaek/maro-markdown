#include "CGFM.h"

#include <pthread.h>
#include <stdlib.h>
#include <strings.h>

// macOS provides libcmark-gfm but does not publish its C headers in the SDK.
// These signatures follow cmark-gfm's public C API. Keep the linker setting
// .linkedLibrary("cmark-gfm") on the SwiftPM target that depends on CGFM.
typedef struct cmark_parser cmark_parser;
typedef struct cmark_node cmark_node;
typedef struct cmark_syntax_extension cmark_syntax_extension;
typedef struct cmark_llist cmark_llist;

extern void cmark_gfm_core_extensions_ensure_registered(void);
extern cmark_syntax_extension *cmark_find_syntax_extension(const char *name);
extern cmark_parser *cmark_parser_new(int options);
extern void cmark_parser_attach_syntax_extension(cmark_parser *parser,
                                                 cmark_syntax_extension *extension);
extern void cmark_parser_feed(cmark_parser *parser, const char *buffer, size_t len);
extern cmark_node *cmark_parser_finish(cmark_parser *parser);
extern void cmark_parser_free(cmark_parser *parser);
extern void cmark_node_free(cmark_node *node);
extern char *cmark_render_html(cmark_node *root, int options, cmark_llist *extensions);
extern const char *cmark_version_string(void);
extern cmark_node *cmark_node_new(int type);
extern int cmark_node_get_type(cmark_node *node);
extern const char *cmark_node_get_literal(cmark_node *node);
extern cmark_node *cmark_node_first_child(cmark_node *node);
extern cmark_node *cmark_node_next(cmark_node *node);
extern int cmark_node_set_on_enter(cmark_node *node, const char *on_enter);
extern int cmark_node_set_on_exit(cmark_node *node, const char *on_exit);
extern int cmark_node_insert_before(cmark_node *node, cmark_node *sibling);
extern int cmark_node_append_child(cmark_node *node, cmark_node *child);

// Values of cmark-gfm's public cmark_node_type enum.
#define CGFM_NODE_BLOCK_QUOTE 0x8002
#define CGFM_NODE_CUSTOM_BLOCK 0x8007
#define CGFM_NODE_PARAGRAPH 0x8008
#define CGFM_NODE_TEXT 0xc001
#define CGFM_NODE_SOFTBREAK 0xc002
#define CGFM_NODE_LINEBREAK 0xc003

// CMARK_OPT_SOURCEPOS is part of cmark-gfm's stable public options enum.
#define CGFM_OPT_SOURCEPOS (1 << 1)
// GitHub enables the cmark-gfm footnote parser and HTML renderer option.
#define CGFM_OPT_FOOTNOTES (1 << 13)

typedef struct {
    const char *marker;
    const char *open_tag;
} cgfm_alert_kind;

// GitHub alerts: a top-level block quote whose first line is only the marker.
#define CGFM_ALERT(marker, kind, title)                                  \
    {marker, "<div class=\"markdown-alert markdown-alert-" kind "\">\n"   \
             "<p class=\"markdown-alert-title\">" title "</p>"}

static const cgfm_alert_kind cgfm_alert_kinds[] = {
    CGFM_ALERT("[!NOTE]", "note", "Note"),
    CGFM_ALERT("[!TIP]", "tip", "Tip"),
    CGFM_ALERT("[!IMPORTANT]", "important", "Important"),
    CGFM_ALERT("[!WARNING]", "warning", "Warning"),
    CGFM_ALERT("[!CAUTION]", "caution", "Caution"),
};

static const cgfm_alert_kind *cgfm_find_alert_kind(const char *literal) {
    if (literal == NULL) {
        return NULL;
    }
    const size_t count = sizeof(cgfm_alert_kinds) / sizeof(cgfm_alert_kinds[0]);
    for (size_t index = 0; index < count; ++index) {
        if (strcasecmp(literal, cgfm_alert_kinds[index].marker) == 0) {
            return &cgfm_alert_kinds[index];
        }
    }
    return NULL;
}

static void cgfm_convert_alert(cmark_node *quote) {
    cmark_node *paragraph = cmark_node_first_child(quote);
    if (paragraph == NULL || cmark_node_get_type(paragraph) != CGFM_NODE_PARAGRAPH) {
        return;
    }
    cmark_node *marker = cmark_node_first_child(paragraph);
    if (marker == NULL || cmark_node_get_type(marker) != CGFM_NODE_TEXT) {
        return;
    }
    const cgfm_alert_kind *kind = cgfm_find_alert_kind(cmark_node_get_literal(marker));
    if (kind == NULL) {
        return;
    }

    // The marker must end its line, and the alert must have a body.
    cmark_node *line_end = cmark_node_next(marker);
    if (line_end != NULL) {
        int type = cmark_node_get_type(line_end);
        if (type != CGFM_NODE_SOFTBREAK && type != CGFM_NODE_LINEBREAK) {
            return;
        }
    } else if (cmark_node_next(paragraph) == NULL) {
        return;
    }

    // Custom blocks render on_enter/on_exit verbatim; both strings are fixed above.
    cmark_node *alert = cmark_node_new(CGFM_NODE_CUSTOM_BLOCK);
    if (alert == NULL) {
        return;
    }
    if (!cmark_node_set_on_enter(alert, kind->open_tag) ||
        !cmark_node_set_on_exit(alert, "</div>") ||
        !cmark_node_insert_before(quote, alert)) {
        cmark_node_free(alert);
        return;
    }

    if (line_end != NULL) {
        cmark_node_free(line_end);
        cmark_node_free(marker);
    } else {
        cmark_node_free(paragraph);
    }
    cmark_node *child;
    while ((child = cmark_node_first_child(quote)) != NULL) {
        if (!cmark_node_append_child(alert, child)) {
            break;
        }
    }
    if (cmark_node_first_child(quote) == NULL) {
        cmark_node_free(quote);
    }
}

static void cgfm_convert_alerts(cmark_node *root) {
    cmark_node *node = cmark_node_first_child(root);
    while (node != NULL) {
        cmark_node *next = cmark_node_next(node);
        if (cmark_node_get_type(node) == CGFM_NODE_BLOCK_QUOTE) {
            cgfm_convert_alert(node);
        }
        node = next;
    }
}

static pthread_once_t cgfm_extension_registration = PTHREAD_ONCE_INIT;

static void cgfm_register_extensions(void) {
    cmark_gfm_core_extensions_ensure_registered();
}

char *cgfm_render_html(const char *markdown_utf8,
                       size_t byte_count,
                       int include_source_positions) {
    if (markdown_utf8 == NULL && byte_count != 0) {
        return NULL;
    }

    if (pthread_once(&cgfm_extension_registration, cgfm_register_extensions) != 0) {
        return NULL;
    }

    // CMARK_OPT_UNSAFE stays off: raw HTML is omitted, which HeadingAnchors in
    // MaroRenderer relies on when it adds heading ids to the rendered HTML.
    cmark_parser *parser = cmark_parser_new(CGFM_OPT_FOOTNOTES);
    if (parser == NULL) {
        return NULL;
    }

    const char *extension_names[] = {
        "table", "strikethrough", "autolink", "tagfilter", "tasklist"
    };
    const size_t extension_count = sizeof(extension_names) / sizeof(extension_names[0]);
    for (size_t index = 0; index < extension_count; ++index) {
        cmark_syntax_extension *extension = cmark_find_syntax_extension(extension_names[index]);
        if (extension == NULL) {
            cmark_parser_free(parser);
            return NULL;
        }
        cmark_parser_attach_syntax_extension(parser, extension);
    }

    cmark_parser_feed(parser, markdown_utf8 == NULL ? "" : markdown_utf8, byte_count);
    cmark_node *root = cmark_parser_finish(parser);
    if (root == NULL) {
        cmark_parser_free(parser);
        return NULL;
    }
    cgfm_convert_alerts(root);

    int render_options = CGFM_OPT_FOOTNOTES;
    if (include_source_positions) {
        render_options |= CGFM_OPT_SOURCEPOS;
    }
    char *html = cmark_render_html(root, render_options, NULL);
    cmark_node_free(root);
    cmark_parser_free(parser);
    return html;
}

void cgfm_free_html(char *html) {
    free(html);
}

const char *cgfm_version_string(void) {
    return cmark_version_string();
}

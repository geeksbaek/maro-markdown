#ifndef CGFM_H
#define CGFM_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Renders UTF-8 GitHub Flavored Markdown to UTF-8 HTML.
// The caller owns the returned string and must release it with cgfm_free_html.
// Returns NULL if the parser, an expected GFM extension, or rendering fails.
char *cgfm_render_html(const char *markdown_utf8,
                       size_t byte_count,
                       int include_source_positions);

void cgfm_free_html(char *html);

// Version of the system cmark-gfm library used at runtime.
const char *cgfm_version_string(void);

#ifdef __cplusplus
}
#endif

#endif

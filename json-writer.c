#include "cache.h"
#include "json-writer.h"

static char g_ch_open[2]  = { '{', '[' };
static char g_ch_close[2] = { '}', ']' };

/*
 * Append JSON-quoted version of the given string to 'out'.
 */
static void append_quoted_string(struct strbuf *out, const char *in)
{
	strbuf_addch(out, '"');
	for (/**/; *in; in++) {
		unsigned char c = (unsigned char)*in;
		if (c == '"')
			strbuf_add(out, "\\\"", 2);
		else if (c == '\\')
			strbuf_add(out, "\\\\", 2);
		else if (c == '\n')
			strbuf_add(out, "\\n", 2);
		else if (c == '\r')
			strbuf_add(out, "\\r", 2);
		else if (c == '\t')
			strbuf_add(out, "\\t", 2);
		else if (c == '\f')
			strbuf_add(out, "\\f", 2);
		else if (c == '\b')
			strbuf_add(out, "\\b", 2);
		else if (c < 0x20)
			strbuf_addf(out, "\\u%04x", c);
		else
			strbuf_addch(out, c);
	}
	strbuf_addch(out, '"');
}


static inline void begin(struct json_writer *jw, int is_array)
{
	ALLOC_GROW(jw->levels, jw->nr + 1, jw->alloc);

	jw->levels[jw->nr].level_is_array = !!is_array;
	jw->levels[jw->nr].level_is_empty = 1;

	strbuf_addch(&jw->json, g_ch_open[!!is_array]);

	jw->nr++;
}

/*
 * Assert that we have an open object at this level.
 */
static void inline assert_in_object(const struct json_writer *jw, const char *key)
{
	if (!jw->nr)
		BUG("object: missing jw_object_begin(): '%s'", key);
	if (jw->levels[jw->nr - 1].level_is_array)
		BUG("object: not in object: '%s'", key);
}

/*
 * Assert that we have an open array at this level.
 */
static void inline assert_in_array(const struct json_writer *jw)
{
	if (!jw->nr)
		BUG("array: missing jw_begin()");
	if (!jw->levels[jw->nr - 1].level_is_array)
		BUG("array: not in array");
}

/*
 * Add comma if we have already seen a member at this level.
 */
static void inline maybe_add_comma(struct json_writer *jw)
{
	if (jw->levels[jw->nr - 1].level_is_empty)
		jw->levels[jw->nr - 1].level_is_empty = 0;
	else
		strbuf_addch(&jw->json, ',');
}

/*
 * Assert that the given JSON object or JSON array has been properly
 * terminated.  (Has closing bracket.)
 */
static void inline assert_is_terminated(const struct json_writer *jw)
{
	if (jw->nr)
		BUG("object: missing jw_end(): '%s'", jw->json.buf);
}

void jw_object_begin(struct json_writer *jw)
{
	begin(jw, 0);
}

void jw_object_string(struct json_writer *jw, const char *key, const char *value)
{
	assert_in_object(jw, key);
	maybe_add_comma(jw);

	append_quoted_string(&jw->json, key);
	strbuf_addch(&jw->json, ':');
	append_quoted_string(&jw->json, value);
}

void jw_object_int(struct json_writer *jw, const char *key, int value)
{
	assert_in_object(jw, key);
	maybe_add_comma(jw);

	append_quoted_string(&jw->json, key);
	strbuf_addf(&jw->json, ":%d", value);
}

void jw_object_uint64(struct json_writer *jw, const char *key, uint64_t value)
{
	assert_in_object(jw, key);
	maybe_add_comma(jw);

	append_quoted_string(&jw->json, key);
	strbuf_addf(&jw->json, ":%"PRIuMAX, value);
}

void jw_object_double(struct json_writer *jw, const char *fmt,
		      const char *key, double value)
{
	assert_in_object(jw, key);
	maybe_add_comma(jw);

	if (!fmt || !*fmt)
		fmt = "%f";

	append_quoted_string(&jw->json, key);
	strbuf_addch(&jw->json, ':');
	strbuf_addf(&jw->json, fmt, value);
}

void jw_object_true(struct json_writer *jw, const char *key)
{
	assert_in_object(jw, key);
	maybe_add_comma(jw);

	append_quoted_string(&jw->json, key);
	strbuf_addstr(&jw->json, ":true");
}

void jw_object_false(struct json_writer *jw, const char *key)
{
	assert_in_object(jw, key);
	maybe_add_comma(jw);

	append_quoted_string(&jw->json, key);
	strbuf_addstr(&jw->json, ":false");
}

void jw_object_null(struct json_writer *jw, const char *key)
{
	assert_in_object(jw, key);
	maybe_add_comma(jw);

	append_quoted_string(&jw->json, key);
	strbuf_addstr(&jw->json, ":null");
}

void jw_object_sub(struct json_writer *jw, const char *key,
		   const struct json_writer *value)
{
	assert_is_terminated(value);

	assert_in_object(jw, key);
	maybe_add_comma(jw);

	append_quoted_string(&jw->json, key);
	strbuf_addch(&jw->json, ':');
	strbuf_addstr(&jw->json, value->json.buf);
}

void jw_object_inline_begin_object(struct json_writer *jw, const char *key)
{
	assert_in_object(jw, key);
	maybe_add_comma(jw);

	append_quoted_string(&jw->json, key);
	strbuf_addch(&jw->json, ':');

	jw_object_begin(jw);
}

void jw_object_inline_begin_array(struct json_writer *jw, const char *key)
{
	assert_in_object(jw, key);
	maybe_add_comma(jw);

	append_quoted_string(&jw->json, key);
	strbuf_addch(&jw->json, ':');

	jw_array_begin(jw);
}

void jw_array_begin(struct json_writer *jw)
{
	begin(jw, 1);
}

void jw_array_string(struct json_writer *jw, const char *value)
{
	assert_in_array(jw);
	maybe_add_comma(jw);

	append_quoted_string(&jw->json, value);
}

void jw_array_int(struct json_writer *jw,int value)
{
	assert_in_array(jw);
	maybe_add_comma(jw);

	strbuf_addf(&jw->json, "%d", value);
}

void jw_array_uint64(struct json_writer *jw, uint64_t value)
{
	assert_in_array(jw);
	maybe_add_comma(jw);

	strbuf_addf(&jw->json, "%"PRIuMAX, value);
}

void jw_array_double(struct json_writer *jw, const char *fmt, double value)
{
	assert_in_array(jw);
	maybe_add_comma(jw);

	if (!fmt || !*fmt)
		fmt = "%f";

	strbuf_addf(&jw->json, fmt, value);
}

void jw_array_true(struct json_writer *jw)
{
	assert_in_array(jw);
	maybe_add_comma(jw);

	strbuf_addstr(&jw->json, "true");
}

void jw_array_false(struct json_writer *jw)
{
	assert_in_array(jw);
	maybe_add_comma(jw);

	strbuf_addstr(&jw->json, "false");
}

void jw_array_null(struct json_writer *jw)
{
	assert_in_array(jw);
	maybe_add_comma(jw);

	strbuf_addstr(&jw->json, "null");
}

void jw_array_sub(struct json_writer *jw, const struct json_writer *value)
{
	assert_is_terminated(value);

	assert_in_array(jw);
	maybe_add_comma(jw);

	strbuf_addstr(&jw->json, value->json.buf);
}


void jw_array_argc_argv(struct json_writer *jw, int argc, const char **argv)
{
	int k;

	for (k = 0; k < argc; k++)
		jw_array_string(jw, argv[k]);
}

void jw_array_argv(struct json_writer *jw, const char **argv)
{
	while (*argv)
		jw_array_string(jw, *argv++);
}

void jw_array_inline_begin_object(struct json_writer *jw)
{
	assert_in_array(jw);
	maybe_add_comma(jw);

	jw_object_begin(jw);
}

void jw_array_inline_begin_array(struct json_writer *jw)
{
	assert_in_array(jw);
	maybe_add_comma(jw);

	jw_array_begin(jw);
}

int jw_is_terminated(const struct json_writer *jw)
{
	return !jw->nr;
}

void jw_end(struct json_writer *jw)
{
	if (!jw->nr)
		BUG("too many jw_end(): '%s'", jw->json.buf);

	jw->nr--;

	strbuf_addch(&jw->json,
		     g_ch_close[jw->levels[jw->nr].level_is_array]);
}

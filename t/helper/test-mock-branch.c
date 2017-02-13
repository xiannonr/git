#include "cache.h"
#include "parse-options.h"

/*
 * Holds the next mark for use in fast-import.
 */
uint32_t next_mark = 1;

/*
 * This helper generates artificial repositories. To do so, it uses a
 * deterministic pseudo random number generator to generate artificial content
 * and content changes.
 *
 * Please note that true randomness (or even cryptigraphically strong) is not
 * required.
 *
 * The following deterministic pseudo-random number generator was adapted from
 * the public domain code on http://burtleburtle.net/bob/rand/smallprng.html.
 */
struct random_context {
	uint32_t a, b, c, d;
};

static inline uint32_t rot(uint32_t x, int bits)
{
	return x << bits | x >> (32 - bits);
}

static uint32_t random_value(struct random_context *context)
{
	uint32_t e = context->a - rot(context->b, 27);
	context->a = context->b ^ rot(context->c, 17);
	context->b = context->c + context->d;
	context->c = context->d + e;
	context->d = e + context->a;
	return context->d;
}

/*
 * Returns a random number in the range 0, ..., range - 1.
 */
static int random_value_in_range(struct random_context *context, int range)
{
	return (int)(random_value(context) *
		     (uint64_t)range / (UINT_MAX + (uint64_t)1));
}

static void random_init(struct random_context *context, uint32_t seed)
{
	int i;

	context->a = 0xf1ea5eed;
	context->b = context->c = context->d = seed;

	for (i = 0; i < 20; i++)
		(void) random_value(context);
}

/*
 * Relatively stupid, but fun, code to generate file content that looks like
 * text in some foreign language.
 */
static void random_word(struct random_context *context, struct strbuf *buf)
{
	static char vowels[] = {
		'a', 'e', 'e', 'i', 'i', 'o', 'u', 'y'
	};
	static char consonants[] = {
		'b', 'c', 'd', 'f', 'g', 'h', 'k', 'l',
		'm', 'n', 'p', 'r', 's', 't', 'v', 'z'
	};
	int syllable_count = 1 + (random_value(context) & 0x3);

	while (syllable_count--) {
		strbuf_addch(buf, consonants[random_value(context) & 0xf]);
		strbuf_addch(buf, vowels[random_value(context) & 0x7]);
	}
}

static void random_sentence(struct random_context *context, struct strbuf *buf)
{
	int word_count = 2 + (random_value(context) & 0xf);

	if (buf->len && buf->buf[buf->len - 1] != '\n')
		strbuf_addch(buf, ' ');

	while (word_count--) {
		random_word(context, buf);
		strbuf_addch(buf, word_count ? ' ' : '.');
	}
}

static void random_paragraph(struct random_context *context, struct strbuf *buf)
{
	int sentence_count = 1 + (random_value(context) & 0x7);

	if (buf->len)
		strbuf_addstr(buf, "\n\n");

	while (sentence_count--)
		random_sentence(context, buf);
}

static void random_content(struct random_context *context, struct strbuf *buf)
{
	int paragraph_count = 1 + (random_value(context) & 0x7);

	while (paragraph_count--)
		random_paragraph(context, buf);
}

/*
 * Relatively stupid, but fun, simulation of what software developers do all
 * day long: change files, add files, occasionally remove files.
 */
static const char *random_new_path(struct random_context *context,
			       struct string_list *state)
{
	static struct strbuf buf = STRBUF_INIT;
	int pos, count, slash, i;
	const char *name, *slash_p;

	strbuf_reset(&buf);
	if (!state->nr) {
		random_word(context, &buf);
		return buf.buf;
	}

	pos = random_value_in_range(context, state->nr);
	name = state->items[pos].string;

	/* determine number of files in the same directory */
	slash_p = strrchr(name, '/');
	slash = slash_p ? slash_p - name + 1 : 0;
	strbuf_add(&buf, name, slash);
	count = 1;
	for (i = pos; i > 0; i--)
		if (strncmp(state->items[i - 1].string, name, slash))
			break;
		else if (!strchr(state->items[i - 1].string + slash, '/'))
			count++;
	for (i = pos + 1; i < state->nr; i++)
		if (strncmp(state->items[i].string, name, slash))
			break;
		else if (!strchr(state->items[i].string + slash, '/'))
			count++;

	/* Depending how many files there are already, add a new directory */
	if (random_value_in_range(context, 20) < count) {
		int len = buf.len;
		for (;;) {
			strbuf_setlen(&buf, len);
			random_word(context, &buf);
			/* Avoid clashes with existing files or directories */
			i = string_list_find_insert_index(state, buf.buf, 1);
			if (i < 0)
				continue;
			strbuf_addch(&buf, '/');
			if (i >= state->nr ||
			    !starts_with(state->items[i].string, buf.buf))
				break;
		}
	}

	/* Make sure that the new path is, in fact, new */
	i = buf.len;
	for (;;) {
		int pos;

		random_word(context, &buf);
		pos = string_list_find_insert_index(state, buf.buf, 1);
		if (pos >= 0) {
			/* Make sure that we do not clash with a directory */
			for (; pos < state->nr; pos++) {
				const char *name = state->items[pos].string;
				char c;

				if (!starts_with(name, buf.buf))
					return buf.buf;
				c = name[buf.len];
				if (c > '/')
					return buf.buf;
				if (c == '/')
					break;
			}
			if (pos == state->nr)
				return buf.buf;
		}
		strbuf_setlen(&buf, i);
	}
}

static void modify_randomly(struct random_context *context, struct strbuf *buf)
{
	int count = 1 + random_value_in_range(context, 5);
	struct strbuf replace = STRBUF_INIT;

	while (count--) {
		int pos = random_value_in_range(context, buf->len);
		const char *eol = strchrnul(buf->buf + pos, '\n');
		int end_pos = pos + random_value_in_range(context,
			eol - buf->buf - pos);
		int new_count;

		while (pos && !isspace(buf->buf[pos - 1]))
			pos--;
		while (end_pos < buf->len && !isspace(buf->buf[end_pos]))
			end_pos++;

		new_count = !pos + random_value_in_range(context,
			(end_pos - pos) / 3);
		/* Do not simply delete ends of paragraphs. */
		if (!new_count && (buf->buf[end_pos] == '\n' ||
				   end_pos == buf->len))
			new_count++;
		strbuf_reset(&replace);
		while (new_count--) {
			if (replace.len)
				strbuf_addch(&replace, ' ');
			random_word(context, &replace);
		}
		if (buf->buf[end_pos] == '\n' || end_pos == buf->len)
			strbuf_addch(&replace, '.');
		strbuf_splice(buf, pos, end_pos - pos,
			      replace.buf, replace.len);
	}

	strbuf_release(&replace);
}

static void handle_file(const char *path, struct strbuf *buf,
			struct string_list *modified)
{
	void *util = NULL;
	if (buf) {
		printf("blob\nmark :%d\ndata %d\n%s\n",
		       next_mark, buf->len, buf->buf);
		util = (void *)(intptr_t)next_mark;
		next_mark++;
	}
	string_list_append(modified, path)->util = util;
}

static void random_work(struct random_context *context,
			struct string_list *state,
			struct string_list *modified)
{
	int count, delete = 0, add = 0, modify;

	/* Obey a totally made-up distribution how many files to remove */
	if (state->nr > 20) {
		delete = !random_value_in_range(context, 40);
		if (!random_value_in_range(context, 100))
			delete++;
	}

	/* Obey a totally made-up distribution how many files to add */
	add = !state->nr;
	if (!random_value_in_range(context, state->nr < 5 ? 2 : 5)) {
		add++;
		if (!random_value_in_range(context, 2)) {
			add++;
			if (!random_value_in_range(context, 3))
				add++;
		}
	}

	/* Obey a totally made-up distribution how many files to modify */
	modify = !(delete + add) + random_value_in_range(context, 5);
	if (modify > state->nr)
		modify = state->nr;

	count = delete;
	while (count--) {
		int pos = random_value_in_range(context, state->nr);

		handle_file(state->items[pos].string, NULL, modified);
		sorted_string_list_delete_item(state, pos, 1);
	}

	count = modify;
	while (count--) {
		int pos = random_value_in_range(context, state->nr);
		struct strbuf buf = STRBUF_INIT;

		strbuf_addstr(&buf, state->items[pos].util);
		modify_randomly(context, &buf);
		handle_file(state->items[pos].string, &buf, modified);
		free(state->items[pos].util);
		state->items[pos].util = strbuf_detach(&buf, NULL);
	}

	count = add;
	while (count--) {
		const char *path = random_new_path(context, state);
		struct strbuf buf = STRBUF_INIT;

		random_content(context, &buf);
		handle_file(path, &buf, modified);
		string_list_insert(state, path)->util =
			strbuf_detach(&buf, NULL);
	}
}

static void random_commit_message(struct random_context *context,
				  struct strbuf *buf)
{
	int count = 3 + random_value_in_range(context, 4);

	while (count--) {
		if (buf->len)
			strbuf_addch(buf, ' ');
		random_word(context, buf);
	}

	count = random_value_in_range(context, 5);
	while (count--)
		random_paragraph(context, buf);
}

static void assert_sorted(struct string_list *list)
{
	int i;

	for (i = 1; i < list->nr; i++)
		if (strcmp(list->items[i - 1].string, list->items[i].string) >= 0)
			die("Not sorted @%d/%d: %s, %s", i, list->nr,
			    list->items[i - 1].string, list->items[i].string);
}

static void random_branch(struct random_context *context, int file_count_goal,
			  const char *ref_name)
{
	struct string_list state = STRING_LIST_INIT_DUP;
	struct string_list modified = STRING_LIST_INIT_DUP;
	uint64_t tick = 1234567890ul;
	uint32_t parent_mark = 0;
	struct strbuf msg = STRBUF_INIT;

	while (state.nr < file_count_goal) {
		struct string_list_item *item;
		int i;

assert_sorted(&state);
		random_work(context, &state, &modified);
		strbuf_reset(&msg);
		random_commit_message(context, &msg);

		printf("commit %s\n"
		       "mark :%d\n"
		       "author A U Thor <author@email.com> %" PRIu64 " -0400\n"
		       "committer C O M Mitter <committer@mitter.com> "
		       "%" PRIu64 " -0400\n"
		       "data %d\n%s\n",
		       ref_name, next_mark, tick, tick, msg.len, msg.buf);
		if (parent_mark)
			printf("from :%d\n", parent_mark);
		for (i = 0, item = modified.items; i < modified.nr; i++, item++)
			if (item->util)
				printf("M 644 :%d %s\n",
				       (int)(intptr_t)item->util, item->string);
			else
				printf("D %s\n", item->string);
		string_list_clear(&modified, 0);

		tick += 1 + random_value_in_range(context, 600);
		parent_mark = next_mark++;
	}
}

int cmd_main(int argc, const char **argv)
{
	struct random_context context;
	int seed = 123, target_file_count = 50;
	const char *ref_name = "refs/mock";
	const char * const usage[] = { argv[0], NULL };
	struct option options[] = {
		OPT_INTEGER(0, "seed", &seed,
			"seed number for the pseudo-random number generator"),
		OPT_INTEGER(0, "target-file-count", &target_file_count,
			"stop generating revisions at this number of files"),
		OPT_STRING(0, "ref-name", &ref_name, "ref-name",
			   "the name of the ref to hold the generated history"),
		OPT_END(),
	};

	argc = parse_options(argc, (const char **)argv,
		NULL, options, usage, 0);
	if (argc)
		usage_with_options(usage, options);

	setup_git_directory();

	random_init(&context, seed);
	random_branch(&context, target_file_count, ref_name);

	return 0;
}

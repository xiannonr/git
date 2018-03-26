#include "cache.h"
#include "json-writer.h"

const char *expect_obj1 = "{\"a\":\"abc\",\"b\":42,\"c\":true}";
const char *expect_obj2 = "{\"a\":-1,\"b\":2147483647,\"c\":0}";
const char *expect_obj3 = "{\"a\":0,\"b\":4294967295,\"c\":18446744073709551615}";
const char *expect_obj4 = "{\"t\":true,\"f\":false,\"n\":null}";
const char *expect_obj5 = "{\"abc\\tdef\":\"abc\\\\def\"}";

struct json_writer obj1 = JSON_WRITER_INIT;
struct json_writer obj2 = JSON_WRITER_INIT;
struct json_writer obj3 = JSON_WRITER_INIT;
struct json_writer obj4 = JSON_WRITER_INIT;
struct json_writer obj5 = JSON_WRITER_INIT;


void make_obj1(void)
{
	jw_object_begin(&obj1);
	{
		jw_object_string(&obj1, "a", "abc");
		jw_object_int(&obj1, "b", 42);
		jw_object_true(&obj1, "c");
	}
	jw_end(&obj1);
}

void make_obj2(void)
{
	jw_object_begin(&obj2);
	{
		jw_object_int(&obj2, "a", -1);
		jw_object_int(&obj2, "b", 0x7fffffff);
		jw_object_int(&obj2, "c", 0);
	}
	jw_end(&obj2);
}

void make_obj3(void)
{
	jw_object_begin(&obj3);
	{
		jw_object_uint64(&obj3, "a", 0);
		jw_object_uint64(&obj3, "b", 0xffffffff);
		jw_object_uint64(&obj3, "c", 0xffffffffffffffff);
	}
	jw_end(&obj3);
}

void make_obj4(void)
{
	jw_object_begin(&obj4);
	{
		jw_object_true(&obj4, "t");
		jw_object_false(&obj4, "f");
		jw_object_null(&obj4, "n");
	}
	jw_end(&obj4);
}

void make_obj5(void)
{
	jw_object_begin(&obj5);
	{
		jw_object_string(&obj5, "abc" "\x09" "def", "abc" "\\" "def");
	}
	jw_end(&obj5);
}

const char *expect_arr1 = "[\"abc\",42,true]";
const char *expect_arr2 = "[-1,2147483647,0]";
const char *expect_arr3 = "[0,4294967295,18446744073709551615]";
const char *expect_arr4 = "[true,false,null]";

struct json_writer arr1 = JSON_WRITER_INIT;
struct json_writer arr2 = JSON_WRITER_INIT;
struct json_writer arr3 = JSON_WRITER_INIT;
struct json_writer arr4 = JSON_WRITER_INIT;

void make_arr1(void)
{
	jw_array_begin(&arr1);
	{
		jw_array_string(&arr1, "abc");
		jw_array_int(&arr1, 42);
		jw_array_true(&arr1);
	}
	jw_end(&arr1);
}

void make_arr2(void)
{
	jw_array_begin(&arr2);
	{
		jw_array_int(&arr2, -1);
		jw_array_int(&arr2, 0x7fffffff);
		jw_array_int(&arr2, 0);
	}
	jw_end(&arr2);
}

void make_arr3(void)
{
	jw_array_begin(&arr3);
	{
		jw_array_uint64(&arr3, 0);
		jw_array_uint64(&arr3, 0xffffffff);
		jw_array_uint64(&arr3, 0xffffffffffffffff);
	}
	jw_end(&arr3);
}

void make_arr4(void)
{
	jw_array_begin(&arr4);
	{
		jw_array_true(&arr4);
		jw_array_false(&arr4);
		jw_array_null(&arr4);
	}
	jw_end(&arr4);
}

char *expect_nest1 =
	"{\"obj1\":{\"a\":\"abc\",\"b\":42,\"c\":true},\"arr1\":[\"abc\",42,true]}";

struct json_writer nest1 = JSON_WRITER_INIT;

void make_nest1(void)
{
	jw_object_begin(&nest1);
	{
		jw_object_sub(&nest1, "obj1", &obj1);
		jw_object_sub(&nest1, "arr1", &arr1);
	}
	jw_end(&nest1);
}

char *expect_inline1 =
	"{\"obj1\":{\"a\":\"abc\",\"b\":42,\"c\":true},\"arr1\":[\"abc\",42,true]}";
struct json_writer inline1 = JSON_WRITER_INIT;


void make_inline1(void)
{
	jw_object_begin(&inline1);
	{
		jw_object_inline_begin_object(&inline1, "obj1");
		{
			jw_object_string(&inline1, "a", "abc");
			jw_object_int(&inline1, "b", 42);
			jw_object_true(&inline1, "c");
		}
		jw_end(&inline1);
		jw_object_inline_begin_array(&inline1, "arr1");
		{
			jw_array_string(&inline1, "abc");
			jw_array_int(&inline1, 42);
			jw_array_true(&inline1);
		}
		jw_end(&inline1);
	}
	jw_end(&inline1);
}

char *expect_inline2 =
	"[[1,2],[3,4],{\"a\":\"abc\"}]";
struct json_writer inline2 = JSON_WRITER_INIT;

void make_inline2(void)
{
	jw_array_begin(&inline2);
	{
		jw_array_inline_begin_array(&inline2);
		{
			jw_array_int(&inline2, 1);
			jw_array_int(&inline2, 2);
		}
		jw_end(&inline2);
		jw_array_inline_begin_array(&inline2);
		{
			jw_array_int(&inline2, 3);
			jw_array_int(&inline2, 4);
		}
		jw_end(&inline2);
		jw_array_inline_begin_object(&inline2);
		{
			jw_object_string(&inline2, "a", "abc");
		}
		jw_end(&inline2);
	}
	jw_end(&inline2);
}


void cmp(const char *test, const struct json_writer *jw, const char *exp)
{
	if (!strcmp(jw->json.buf, exp))
		return;

	printf("error[%s]: observed '%s' expected '%s'\n",
	       test, jw->json.buf, exp);
	exit(1);
}

#define t(v) do { make_##v(); cmp(#v, &v, expect_##v); } while (0)

/*
 * Run some basic regression tests with some known patterns.
 * These tests also demonstrate how to use the jw_ API.
 */
int unit_tests(void)
{
	t(obj1);
	t(obj2);
	t(obj3);
	t(obj4);
	t(obj5);

	t(arr1);
	t(arr2);
	t(arr3);
	t(arr4);

	t(nest1);

	t(inline1);
	t(inline2);

	return 0;
}

#define STMT(s) do { s } while (0)

#define PARAM(tok, lbl, p) \
	STMT( if (!(p) || (*(p) == '@')) \
		die("token '%s' requires '%s' parameter, but saw: '%s'", \
		    tok, lbl, p); )

#define FMT() \
	STMT( fmt = argv[++k]; \
	      PARAM(a_k, "fmt", fmt); )

#define KEY() \
	STMT( key = argv[++k]; \
	      PARAM(a_k, "key", key); )

#define VAL() \
	STMT( val = argv[++k]; \
	      PARAM(a_k, "val", val); )

#define VAL_INT() \
	STMT( VAL(); \
	      v_int = strtol(val, &endptr, 10); \
	      if (*endptr || errno == ERANGE) \
		die("invalid '%s' value: '%s'",	a_k, val); )

#define VAL_UINT64() \
	STMT( VAL(); \
	      v_uint64 = strtoull(val, &endptr, 10); \
	      if (*endptr || errno == ERANGE) \
		die("invalid '%s' value: '%s'",	a_k, val); )

#define VAL_DOUBLE() \
	STMT( VAL(); \
	      v_double = strtod(val, &endptr); \
	      if (*endptr || errno == ERANGE) \
		die("invalid '%s' value: '%s'",	a_k, val); )

static inline int scripted(int argc, const char **argv)
{
	struct json_writer jw = JSON_WRITER_INIT;
	int k;

	if (!strcmp(argv[0], "@object"))
		jw_object_begin(&jw);
	else if (!strcmp(argv[0], "@array"))
		jw_array_begin(&jw);
	else
		die("first script term must be '@object' or '@array': '%s'", argv[0]);

	for (k = 1; k < argc; k++) {
		const char *a_k = argv[k];
		const char *key;
		const char *val;
		const char *fmt;
		char *endptr;
		int v_int;
		uint64_t v_uint64;
		double v_double;

		if (!strcmp(a_k, "@end")) {
			jw_end(&jw);
			continue;
		}

		if (!strcmp(a_k, "@object-string")) {
			KEY();
			VAL();
			jw_object_string(&jw, key, val);
			continue;
		}
		if (!strcmp(a_k, "@object-int")) {
			KEY();
			VAL_INT();
			jw_object_int(&jw, key, v_int);
			continue;
		}
		if (!strcmp(a_k, "@object-uint64")) {
			KEY();
			VAL_UINT64();
			jw_object_uint64(&jw, key, v_uint64);
			continue;
		}
		if (!strcmp(a_k, "@object-double")) {
			FMT();
			KEY();
			VAL_DOUBLE();
			jw_object_double(&jw, fmt, key, v_double);
			continue;
		}
		if (!strcmp(a_k, "@object-true")) {
			KEY();
			jw_object_true(&jw, key);
			continue;
		}
		if (!strcmp(a_k, "@object-false")) {
			KEY();
			jw_object_false(&jw, key);
			continue;
		}
		if (!strcmp(a_k, "@object-null")) {
			KEY();
			jw_object_null(&jw, key);
			continue;
		}
		if (!strcmp(a_k, "@object-object")) {
			KEY();
			jw_object_inline_begin_object(&jw, key);
			continue;
		}
		if (!strcmp(a_k, "@object-array")) {
			KEY();
			jw_object_inline_begin_array(&jw, key);
			continue;
		}

		if (!strcmp(a_k, "@array-string")) {
			VAL();
			jw_array_string(&jw, val);
			continue;
		}
		if (!strcmp(a_k, "@array-int")) {
			VAL_INT();
			jw_array_int(&jw, v_int);
			continue;
		}
		if (!strcmp(a_k, "@array-uint64")) {
			VAL_UINT64();
			jw_array_uint64(&jw, v_uint64);
			continue;
		}
		if (!strcmp(a_k, "@array-double")) {
			FMT();
			VAL_DOUBLE();
			jw_array_double(&jw, fmt, v_double);
			continue;
		}
		if (!strcmp(a_k, "@array-true")) {
			jw_array_true(&jw);
			continue;
		}
		if (!strcmp(a_k, "@array-false")) {
			jw_array_false(&jw);
			continue;
		}
		if (!strcmp(a_k, "@array-null")) {
			jw_array_null(&jw);
			continue;
		}
		if (!strcmp(a_k, "@array-object")) {
			jw_array_inline_begin_object(&jw);
			continue;
		}
		if (!strcmp(a_k, "@array-array")) {
			jw_array_inline_begin_array(&jw);
			continue;
		}

		die("unrecognized token: '%s'", a_k);
	}

	if (!jw_is_terminated(&jw))
		die("json not terminated: '%s'", jw.json.buf);

	printf("%s\n", jw.json.buf);

	strbuf_release(&jw.json);
	return 0;
}

static inline int my_usage(void)
{
	die("usage: '-u' | '@object ... @end' | '@array ... @end'");
}

int cmd_main(int argc, const char **argv)
{
	if (argc == 1)
		return my_usage();

	if (argv[1][0] == '-') {
		if (!strcmp(argv[1], "-u"))
			return unit_tests();

		return my_usage();
	}

	return scripted(argc - 1, argv + 1);
}

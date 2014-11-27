#ifndef GIT_FSCK_H
#define GIT_FSCK_H

#define FSCK_ERROR 1
#define FSCK_WARN 2

struct fsck_options;

enum fsck_msg_id {
	FSCK_MSG_NULL_SHA1,
	FSCK_MSG_FULL_PATHNAME,
	FSCK_MSG_EMPTY_NAME,
	FSCK_MSG_HAS_DOT,
	FSCK_MSG_HAS_DOTDOT,
	FSCK_MSG_HAS_DOTGIT,
	FSCK_MSG_ZERO_PADDED_FILEMODE,
	FSCK_MSG_BAD_FILEMODE,
	FSCK_MSG_DUPLICATE_ENTRIES,
	FSCK_MSG_NOT_SORTED,
	FSCK_MSG_NUL_IN_HEADER,
	FSCK_MSG_UNTERMINATED_HEADER,
	FSCK_MSG_MISSING_NAME_BEFORE_EMAIL,
	FSCK_MSG_BAD_NAME,
	FSCK_MSG_MISSING_EMAIL,
	FSCK_MSG_MISSING_SPACE_BEFORE_EMAIL,
	FSCK_MSG_BAD_EMAIL,
	FSCK_MSG_MISSING_SPACE_BEFORE_DATE,
	FSCK_MSG_ZERO_PADDED_DATE,
	FSCK_MSG_DATE_OVERFLOW,
	FSCK_MSG_BAD_DATE,
	FSCK_MSG_BAD_TIMEZONE,
	FSCK_MSG_MISSING_TREE,
	FSCK_MSG_BAD_TREE_SHA1,
	FSCK_MSG_BAD_PARENT_SHA1,
	FSCK_MSG_MISSING_GRAFT,
	FSCK_MSG_MISSING_PARENT,
	FSCK_MSG_MISSING_AUTHOR,
	FSCK_MSG_MISSING_COMMITTER,
	FSCK_MSG_INVALID_TREE,
	FSCK_MSG_MISSING_TAG_OBJECT,
	FSCK_MSG_TAG_OBJECT_NOT_TAG,
	FSCK_MSG_MISSING_OBJECT,
	FSCK_MSG_INVALID_OBJECT_SHA1,
	FSCK_MSG_MISSING_TYPE_ENTRY,
	FSCK_MSG_MISSING_TYPE,
	FSCK_MSG_INVALID_TYPE,
	FSCK_MSG_MISSING_TAG_ENTRY,
	FSCK_MSG_MISSING_TAG,
	FSCK_MSG_INVALID_TAG_NAME,
	FSCK_MSG_MISSING_TAGGER_ENTRY,
	FSCK_MSG_INVALID_TAG_OBJECT,
	FSCK_MSG_UNKNOWN_TYPE
};

int fsck_msg_type(enum fsck_msg_id msg_id, struct fsck_options *options);

/*
 * callback function for fsck_walk
 * type is the expected type of the object or OBJ_ANY
 * the return value is:
 *     0	everything OK
 *     <0	error signaled and abort
 *     >0	error signaled and do not abort
 */
typedef int (*fsck_walk_func)(struct object *obj, int type, void *data, struct fsck_options *options);

/* callback for fsck_object, type is FSCK_ERROR or FSCK_WARN */
typedef int (*fsck_error)(struct object *obj, int type, const char *message);

int fsck_error_function(struct object *obj, int type, const char *message);

struct fsck_options {
	fsck_walk_func walk;
	fsck_error error_func;
	int strict:1;
};

#define FSCK_OPTIONS_INIT { NULL, fsck_error_function, 0 }
#define FSCK_OPTIONS_STRICT { NULL, fsck_error_function, 1 }

/* descend in all linked child objects
 * the return value is:
 *    -1	error in processing the object
 *    <0	return value of the callback, which lead to an abort
 *    >0	return value of the first signaled error >0 (in the case of no other errors)
 *    0		everything OK
 */
int fsck_walk(struct object *obj, void *data, struct fsck_options *options);
/* If NULL is passed for data, we assume the object is local and read it. */
int fsck_object(struct object *obj, void *data, unsigned long size,
	struct fsck_options *options);

#endif

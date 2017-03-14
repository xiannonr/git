#ifndef CNG_SHA1_H
#define CNG_SHA1_H

#include <bcrypt.h>
/* imap-send.c wants to use OpenSSL's X509_NAME type: undefine the constant */
//#undef X509_NAME

typedef struct {
	BCRYPT_HASH_HANDLE handle;
	void *data;
} cng_SHA_CTX;

int cng_SHA1_Init(cng_SHA_CTX *c);
int cng_SHA1_Update(cng_SHA_CTX *c, const void *p, unsigned long n);
int cng_SHA1_Final(unsigned char *hash, cng_SHA_CTX *c);

#define platform_SHA_CTX	cng_SHA_CTX
#define platform_SHA1_Init	cng_SHA1_Init
#define platform_SHA1_Update	cng_SHA1_Update
#define platform_SHA1_Final	cng_SHA1_Final

#endif

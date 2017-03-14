#ifndef CRYPTOAPI_SHA1_H
#define CRYPTOAPI_SHA1_H

#include <wincrypt.h>
/* imap-send.c wants to use OpenSSL's X509_NAME type: undefine the constant */
#undef X509_NAME

typedef HCRYPTHASH cryptoapi_SHA_CTX;

int cryptoapi_SHA1_Init(cryptoapi_SHA_CTX *c);
int cryptoapi_SHA1_Update(cryptoapi_SHA_CTX *c, const void *p, unsigned long n);
int cryptoapi_SHA1_Final(unsigned char *hash, cryptoapi_SHA_CTX *c);

#define platform_SHA_CTX	cryptoapi_SHA_CTX
#define platform_SHA1_Init	cryptoapi_SHA1_Init
#define platform_SHA1_Update	cryptoapi_SHA1_Update
#define platform_SHA1_Final	cryptoapi_SHA1_Final

#endif

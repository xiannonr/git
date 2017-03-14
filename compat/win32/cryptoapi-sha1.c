#include "cache.h"
#include "cryptoapi-sha1.h"

static int initialized;
static HCRYPTPROV cryptoapi_provider;

int cryptoapi_SHA1_Init(cryptoapi_SHA_CTX *c)
{
	if (!initialized) {
		if (!CryptAcquireContext(&cryptoapi_provider, NULL, NULL,
					 PROV_RSA_FULL, 0))
			die(_("Could not acquire Crypto API provider"));
		initialized = 1;
	}

	return !CryptCreateHash(cryptoapi_provider, CALG_SHA1, 0, 0, c);
}

int cryptoapi_SHA1_Update(cryptoapi_SHA_CTX *c, const void *p, unsigned long n)
{
	return !CryptHashData(*c, (BYTE *)p, (DWORD)n, 0);
}

int cryptoapi_SHA1_Final(unsigned char *hash, cryptoapi_SHA_CTX *c)
{
	DWORD len = GIT_SHA1_RAWSZ;
	int ret = !CryptGetHashParam(*c, HP_HASHVAL, hash, &len, 0);

	assert(len == GIT_SHA1_RAWSZ);
	CryptDestroyHash(*c);

	return ret;
}

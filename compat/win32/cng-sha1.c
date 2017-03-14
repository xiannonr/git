#include "cache.h"
#include "cng-sha1.h"

static int initialized;
static BCRYPT_ALG_HANDLE algo;
static DWORD object_size;

int cng_SHA1_Init(cng_SHA_CTX *c)
{
	if (!initialized) {
		DWORD dummy;

		if (BCryptOpenAlgorithmProvider(&algo, BCRYPT_SHA1_ALGORITHM,
						NULL, 0) < 0)
			die(_("Could not acquire CNG SHA-1 algorithm"));
		if (BCryptGetProperty(algo, BCRYPT_OBJECT_LENGTH,
				      (BYTE *)&object_size, sizeof(object_size),
				      &dummy, 0) < 0)
			die(_("Could not query hash object size"));
		initialized = 1;
	}

	c->data = xmalloc(object_size);

	if (BCryptCreateHash(algo, &c->handle, c->data, object_size,
			     NULL, 0, 0) < 0)
		return error(_("Could not create hash object"));
	return 0;
}

int cng_SHA1_Update(cng_SHA_CTX *c, const void *p, unsigned long n)
{
	if (BCryptHashData(c->handle, (BYTE *)p, n, 0) < 0)
		return error(_("Failed to hash data"));
	return 0;
}

int cng_SHA1_Final(unsigned char *hash, cng_SHA_CTX *c)
{
	DWORD ret = BCryptFinishHash(c->handle, hash, GIT_SHA1_RAWSZ, 0);

	BCryptDestroyHash(c->handle);
	free(c->data);

	return ret < 0 ? -1 : 0;
}

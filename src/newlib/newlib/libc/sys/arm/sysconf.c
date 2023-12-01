/* libc/sys/arm/sysconf.c - The sysconf function */

/* Copyright 2018, ST Microelectronics */

#include <unistd.h>
#include <errno.h>

long sysconf(int name)
{
	switch (name)
	{
	case _SC_PAGESIZE:
		return 4096;

	default:
		errno = EINVAL;
		return -1;
	}
	return -1; /* Can't get here */
}

/* uname.cc
   Written by Steve Chamberlain of Cygnus Support, sac@cygnus.com
   Rewritten by Geoffrey Noer of Cygnus Solutions, noer@cygnus.com

This file is part of Cygwin.

This software is a copyrighted work licensed under the terms of the
Cygwin license.  Please consult the file "CYGWIN_LICENSE" for
details. */

#include "winsup.h"
#include <sys/utsname.h>
#include <netdb.h>
#include "cygwin_version.h"
#include "cygtls.h"

extern "C" int cygwin_gethostname (char *__name, size_t __len);
extern "C" int getdomainname (char *__name, size_t __len);

#if __GNUC__ >= 8
#define ATTRIBUTE_NONSTRING __attribute__ ((nonstring))
#else
#define ATTRIBUTE_NONSTRING
#endif

/* uname: POSIX 4.4.1.1 */

/* New entrypoint for applications since API 335 */
extern "C" int
uname_x (struct utsname *name)
{
  __try
    {
      char buf[NI_MAXHOST + 1] ATTRIBUTE_NONSTRING;
      char *snp = strstr (cygwin_version.dll_build_date, "SNP");

      memset (name, 0, sizeof (*name));
      /* sysname */
      __small_sprintf (name->sysname, "CYGWIN_%s-%u",
		       wincap.osname (), wincap.build_number ());
      /* nodename */
      memset (buf, 0, sizeof buf);
      cygwin_gethostname (buf, sizeof buf - 1);
      strncat (name->nodename, buf, sizeof (name->nodename) - 1);
      /* release */
      __small_sprintf (name->release, "%d.%d.%d-%d.",
		       cygwin_version.dll_major / 1000,
		       cygwin_version.dll_major % 1000,
		       cygwin_version.dll_minor,
		       cygwin_version.api_minor);
      /* version */
      stpcpy (name->version, cygwin_version.dll_build_date);
      if (snp)
	name->version[snp - cygwin_version.dll_build_date] = '\0';
      strcat (name->version, " UTC");
      /* machine */
      switch (wincap.cpu_arch ())
	{
	  case PROCESSOR_ARCHITECTURE_AMD64:
	    strcat (name->release, strcpy (name->machine, "x86_64"));
	    break;
	  default:
	    strcpy (name->machine, "unknown");
	    break;
	}
      if (snp)
	strcat (name->release, ".snap");
      /* domainame */
      memset (buf, 0, sizeof buf);
      getdomainname (buf, sizeof buf - 1);
      strncat (name->domainname, buf, sizeof (name->domainname) - 1);
    }
  __except (EFAULT) { return -1; }
  __endtry
  return 0;
}

/* Old entrypoint for applications up to API 334 */
struct old_utsname
{
  char sysname[20];
  char nodename[20];
  char release[20];
  char version[20];
  char machine[20];
};

extern "C" int
uname (struct utsname *in_name)
{
  struct old_utsname *name = (struct old_utsname *) in_name;
  __try
    {
      char *snp = strstr  (cygwin_version.dll_build_date, "SNP");

      memset (name, 0, sizeof (*name));
      __small_sprintf (name->sysname, "CYGWIN_%s", wincap.osname ());

      /* Computer name */
      cygwin_gethostname (name->nodename, sizeof (name->nodename) - 1);

      /* Cygwin dll release */
      __small_sprintf (name->release, "%d.%d.%d%s(%d.%d/%d/%d)",
		       cygwin_version.dll_major / 1000,
		       cygwin_version.dll_major % 1000,
		       cygwin_version.dll_minor,
		       snp ? "s" : "",
		       cygwin_version.api_major,
		       cygwin_version.api_minor,
		       cygwin_version.shared_data,
		       cygwin_version.mount_registry);

      /* Cygwin "version" aka build date */
      strcpy (name->version, cygwin_version.dll_build_date);
      if (snp)
	name->version[snp - cygwin_version.dll_build_date] = '\0';

      /* CPU type */
      switch (wincap.cpu_arch ())
	{
	  case PROCESSOR_ARCHITECTURE_AMD64:
	    strcpy (name->machine, "x86_64");
	    break;
	  default:
	    strcpy (name->machine, "unknown");
	    break;
	}
    }
  __except (EFAULT)
    {
      return -1;
    }
  __endtry
  return 0;
}

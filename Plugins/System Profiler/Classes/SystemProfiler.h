
#import <IOKit/IOKitLib.h>

#import "Textual.h"

/* The App Store build reads neither the Mac's uptime nor its disk space:
 these commands send them to other people, and Apple allows those APIs only
 for uses that stay on the Mac */
#define TPI_SP_SendsUptimeAndDiskSpace		(TEXTUAL_BUILT_FOR_APP_STORE_DISTRIBUTION == 0)

#include <mach/mach.h>
#include <mach/mach_host.h>
#include <mach/host_info.h>
#include <mach/mach_vm.h>

#import <libproc.h>

#include <sys/mount.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#include <sys/socket.h>
#include <sys/utsname.h>

#include <ifaddrs.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <net/route.h>

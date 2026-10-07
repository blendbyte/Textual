
#import "TXApplicationPrivate.h"

int main(int argc, const char *argv[])
{
	@autoreleasepool {
#ifndef DEBUG
		if ([TXApplication checkForOtherCopiesOfTextualRunning] == NO) {
			exit(0);
		}
#endif

		NSApplicationMain(argc, argv);
	}

	return 0;
}

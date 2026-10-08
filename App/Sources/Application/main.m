#import "TXApplicationPrivate.h"

int main(int argc, const char *argv[])
{
	@autoreleasepool {
		/* When Textual restarts itself (after importing settings), the new
		 copy waits for the old one to quit, at most ten seconds. The old one
		 leaves its process identifier in the preferences: a sandboxed app
		 can't pass launch arguments to the copy it starts. */
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

		NSDictionary *restart = [defaults dictionaryForKey:@"TextualRestartAfterProcess"];

		[defaults removeObjectForKey:@"TextualRestartAfterProcess"];

		pid_t restartAfterProcess = (pid_t)[restart[@"processIdentifier"] integerValue];

		NSDate *restartRequested = restart[@"date"];

		if (restartAfterProcess > 0 && [restartRequested isKindOfClass:[NSDate class]] && restartRequested.timeIntervalSinceNow > -60) {
			for (NSUInteger attempt = 0; attempt < 100; attempt++) {
				NSRunningApplication *application = [NSRunningApplication runningApplicationWithProcessIdentifier:restartAfterProcess];

				if (application == nil || application.terminated) {
					break;
				}

				usleep(100000);
			}
		}

#ifndef DEBUG
		if ([TXApplication checkForOtherCopiesOfTextualRunning] == NO) {
			exit(0);
		}
#endif

		NSApplicationMain(argc, argv);
	}

	return 0;
}

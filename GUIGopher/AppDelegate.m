#import "AppDelegate.h"
#import "GopherWindowController.h"

@interface AppDelegate ()
@property (nonatomic, strong) GopherWindowController *windowController;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.windowController = [[GopherWindowController alloc] init];
    [self.windowController showWindow:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end

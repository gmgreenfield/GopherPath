#import "AppDelegate.h"
#import "GopherWindowController.h"

@interface AppDelegate ()
@property (nonatomic, strong) GopherWindowController *windowController;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.windowController = [[GopherWindowController alloc] init];
    [self installApplicationMenu];
    [self.windowController showWindow:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)installApplicationMenu {
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@"GopherPath"];
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] initWithTitle:@"GopherPath" action:nil keyEquivalent:@""];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"GopherPath"];
    NSMenuItem *aboutItem = [[NSMenuItem alloc] initWithTitle:@"About GopherPath" action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    aboutItem.target = NSApp;
    [appMenu addItem:aboutItem];
    [appMenu addItem:NSMenuItem.separatorItem];
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit GopherPath" action:@selector(terminate:) keyEquivalent:@"q"];
    quitItem.target = NSApp;
    [appMenu addItem:quitItem];
    appMenuItem.submenu = appMenu;
    [mainMenu addItem:appMenuItem];

    NSMenuItem *navigationItem = [[NSMenuItem alloc] initWithTitle:@"Navigate" action:nil keyEquivalent:@""];
    NSMenu *navigationMenu = [[NSMenu alloc] initWithTitle:@"Navigate"];
    NSArray<NSDictionary<NSString *, id> *> *commands = @[
        @{@"title": @"Back", @"action": NSStringFromSelector(@selector(goBack:)), @"key": @"[", @"modifiers": @(NSEventModifierFlagCommand)},
        @{@"title": @"Forward", @"action": NSStringFromSelector(@selector(goForward:)), @"key": @"]", @"modifiers": @(NSEventModifierFlagCommand)},
        @{@"title": @"Reload", @"action": NSStringFromSelector(@selector(reloadOrStop:)), @"key": @"r", @"modifiers": @(NSEventModifierFlagCommand)},
        @{@"title": @"Stop", @"action": NSStringFromSelector(@selector(stopLoading:)), @"key": @"\e", @"modifiers": @(0)},
        @{@"title": @"Focus Address Bar", @"action": NSStringFromSelector(@selector(focusAddressBar:)), @"key": @"l", @"modifiers": @(NSEventModifierFlagCommand)}
    ];
    for (NSDictionary *command in commands) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:command[@"title"] action:NSSelectorFromString(command[@"action"]) keyEquivalent:command[@"key"]];
        item.target = self.windowController;
        item.keyEquivalentModifierMask = [command[@"modifiers"] unsignedIntegerValue];
        [navigationMenu addItem:item];
    }
    navigationItem.submenu = navigationMenu;
    [mainMenu addItem:navigationItem];
    NSApp.mainMenu = mainMenu;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end

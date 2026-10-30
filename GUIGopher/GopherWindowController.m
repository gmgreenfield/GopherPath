#import "GopherWindowController.h"

@interface GopherWindowController () <NSTextFieldDelegate>
@property (nonatomic, strong) NSSplitView *splitView;
@property (nonatomic, strong) NSOutlineView *sidebar;
@property (nonatomic, strong) NSTableView *itemsTable;
@property (nonatomic, strong) NSTextField *addressField;
@property (nonatomic, strong) NSTextField *welcomeLabel;
@end

@implementation GopherWindowController

- (instancetype)init {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1024, 680)
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    self = [super initWithWindow:window];
    if (self) {
        window.title = @"GUI Gopher";
        window.minSize = NSMakeSize(720, 460);
        [self buildInterface];
    }
    return self;
}

- (void)buildInterface {
    NSView *content = self.window.contentView;
    NSVisualEffectView *toolbar = [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
    toolbar.translatesAutoresizingMaskIntoConstraints = NO;
    toolbar.material = NSVisualEffectMaterialTitlebar;
    toolbar.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    [content addSubview:toolbar];

    NSButton *back = [self buttonWithTitle:@"‹" action:nil];
    NSButton *forward = [self buttonWithTitle:@"›" action:nil];
    back.font = [NSFont systemFontOfSize:22 weight:NSFontWeightRegular];
    forward.font = [NSFont systemFontOfSize:22 weight:NSFontWeightRegular];
    back.enabled = NO;
    forward.enabled = NO;
    self.addressField = [[NSTextField alloc] initWithFrame:NSZeroRect];
    self.addressField.translatesAutoresizingMaskIntoConstraints = NO;
    self.addressField.placeholderString = @"Enter a Gopher address…";
    self.addressField.font = [NSFont systemFontOfSize:13];
    self.addressField.bezelStyle = NSTextFieldRoundedBezel;
    self.addressField.delegate = self;
    [toolbar addSubview:back];
    [toolbar addSubview:forward];
    [toolbar addSubview:self.addressField];

    self.splitView = [[NSSplitView alloc] initWithFrame:NSZeroRect];
    self.splitView.translatesAutoresizingMaskIntoConstraints = NO;
    self.splitView.vertical = YES;
    self.splitView.dividerStyle = NSSplitViewDividerStyleThin;
    [content addSubview:self.splitView];

    NSView *side = [[NSView alloc] initWithFrame:NSZeroRect];
    NSView *main = [[NSView alloc] initWithFrame:NSZeroRect];
    [self.splitView addSubview:side];
    [self.splitView addSubview:main];

    self.sidebar = [[NSOutlineView alloc] initWithFrame:NSZeroRect];
    NSTableColumn *sidebarColumn = [[NSTableColumn alloc] initWithIdentifier:@"sidebar"];
    sidebarColumn.title = @"LIBRARY";
    [self.sidebar addTableColumn:sidebarColumn];
    self.sidebar.outlineTableColumn = sidebarColumn;
    self.sidebar.headerView = nil;
    self.sidebar.rowSizeStyle = NSTableViewRowSizeStyleDefault;
    self.sidebar.translatesAutoresizingMaskIntoConstraints = NO;
    [side addSubview:self.sidebar];
    [NSLayoutConstraint activateConstraints:@[
        [self.sidebar.leadingAnchor constraintEqualToAnchor:side.leadingAnchor],
        [self.sidebar.trailingAnchor constraintEqualToAnchor:side.trailingAnchor],
        [self.sidebar.topAnchor constraintEqualToAnchor:side.topAnchor],
        [self.sidebar.bottomAnchor constraintEqualToAnchor:side.bottomAnchor]
    ]];

    self.itemsTable = [[NSTableView alloc] initWithFrame:NSZeroRect];
    NSTableColumn *iconColumn = [[NSTableColumn alloc] initWithIdentifier:@"icon"];
    iconColumn.width = 34;
    iconColumn.maxWidth = 34;
    iconColumn.minWidth = 34;
    NSTableColumn *nameColumn = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    nameColumn.title = @"NAME";
    NSTableColumn *descriptionColumn = [[NSTableColumn alloc] initWithIdentifier:@"description"];
    descriptionColumn.title = @"DESCRIPTION";
    [self.itemsTable addTableColumn:iconColumn];
    [self.itemsTable addTableColumn:nameColumn];
    [self.itemsTable addTableColumn:descriptionColumn];
    self.itemsTable.headerView = nil;
    self.itemsTable.rowSizeStyle = NSTableViewRowSizeStyleLarge;
    self.itemsTable.usesAlternatingRowBackgroundColors = YES;
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.hasVerticalScroller = YES;
    scrollView.documentView = self.itemsTable;
    [main addSubview:scrollView];

    self.welcomeLabel = [NSTextField labelWithString:@"A quieter corner of the internet."];
    self.welcomeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.welcomeLabel.font = [NSFont systemFontOfSize:22 weight:NSFontWeightMedium];
    self.welcomeLabel.textColor = NSColor.secondaryLabelColor;
    [main addSubview:self.welcomeLabel];
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.leadingAnchor constraintEqualToAnchor:main.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:main.trailingAnchor],
        [scrollView.topAnchor constraintEqualToAnchor:main.topAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:main.bottomAnchor],
        [self.welcomeLabel.centerXAnchor constraintEqualToAnchor:main.centerXAnchor],
        [self.welcomeLabel.centerYAnchor constraintEqualToAnchor:main.centerYAnchor]
    ]];

    [NSLayoutConstraint activateConstraints:@[
        [toolbar.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [toolbar.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [toolbar.topAnchor constraintEqualToAnchor:content.topAnchor],
        [toolbar.heightAnchor constraintEqualToConstant:54],
        [back.leadingAnchor constraintEqualToAnchor:toolbar.leadingAnchor constant:14],
        [back.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        [back.widthAnchor constraintEqualToConstant:30],
        [forward.leadingAnchor constraintEqualToAnchor:back.trailingAnchor constant:4],
        [forward.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        [forward.widthAnchor constraintEqualToConstant:30],
        [self.addressField.leadingAnchor constraintEqualToAnchor:forward.trailingAnchor constant:14],
        [self.addressField.trailingAnchor constraintEqualToAnchor:toolbar.trailingAnchor constant:-16],
        [self.addressField.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor],
        [self.addressField.heightAnchor constraintEqualToConstant:28],
        [self.splitView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [self.splitView.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [self.splitView.topAnchor constraintEqualToAnchor:toolbar.bottomAnchor],
        [self.splitView.bottomAnchor constraintEqualToAnchor:content.bottomAnchor]
    ]];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.splitView setPosition:220 ofDividerAtIndex:0];
    });
}

- (NSButton *)buttonWithTitle:(NSString *)title action:(SEL)action {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.bezelStyle = NSBezelStyleTexturedRounded;
    return button;
}

@end

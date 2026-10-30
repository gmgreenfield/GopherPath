#import "GopherWindowController.h"
#import "GopherClient.h"
#import "GopherItem.h"

@interface GopherItemsTableView : NSTableView
@end

@implementation GopherItemsTableView
- (void)mouseDown:(NSEvent *)event {
    [super mouseDown:event];
    if (event.clickCount == 1 && self.clickedRow >= 0 && self.clickedRow < self.numberOfRows) [self sendAction:self.action to:self.target];
}
@end

@interface GopherItemRowView : NSTableRowView
@property (nonatomic) BOOL pointerIsInside;
@property (nonatomic, strong) NSTrackingArea *rowTrackingArea;
@end

@implementation GopherItemRowView
- (void)updateTrackingAreas {
    if (self.rowTrackingArea) [self removeTrackingArea:self.rowTrackingArea];
    self.rowTrackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect
                                                       options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect
                                                         owner:self userInfo:nil];
    [self addTrackingArea:self.rowTrackingArea];
    [super updateTrackingAreas];
}
- (void)mouseEntered:(NSEvent *)event { self.pointerIsInside = YES; [self setNeedsDisplay:YES]; }
- (void)mouseExited:(NSEvent *)event { self.pointerIsInside = NO; [self setNeedsDisplay:YES]; }
- (void)drawBackgroundInRect:(NSRect)dirtyRect {
    [super drawBackgroundInRect:dirtyRect];
    if (self.pointerIsInside && !self.isSelected) {
        [[NSColor.controlAccentColor colorWithAlphaComponent:0.08] setFill];
        NSRectFillUsingOperation(dirtyRect, NSCompositingOperationSourceOver);
    }
}
@end

@interface GopherWindowController () <NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, strong) NSTableView *itemsTable;
@property (nonatomic, strong) NSTextField *addressField;
@property (nonatomic, strong) NSTextField *welcomeLabel;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSScrollView *listScrollView;
@property (nonatomic, strong) NSScrollView *readerScrollView;
@property (nonatomic, strong) NSTextView *readerView;
@property (nonatomic, strong) NSButton *backButton;
@property (nonatomic, strong) NSButton *forwardButton;
@property (nonatomic, strong) NSButton *bookmarkButton;
@property (nonatomic, strong) NSButton *reloadStopButton;
@property (nonatomic, strong) NSButton *retryButton;
@property (nonatomic, strong) NSProgressIndicator *progressIndicator;
@property (nonatomic, strong) GopherClient *client;
@property (nonatomic, strong) GopherRequestToken *currentRequestToken;
@property (nonatomic, copy) NSArray<GopherItem *> *items;
@property (nonatomic, strong) NSMutableArray<NSString *> *history;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, NSString *> *> *bookmarks;
@property (nonatomic) NSInteger historyIndex;
@property (nonatomic, copy) NSString *currentHost;
@property (nonatomic) NSInteger currentPort;
@property (nonatomic, copy) NSString *currentSelector;
@property (nonatomic) unichar currentType;
@property (nonatomic, copy) NSString *currentURL;
@property (nonatomic, copy) NSString *currentQuery;
@property (nonatomic) BOOL isLoading;
@end

@implementation GopherWindowController

- (instancetype)init {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1024, 680)
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                                     backing:NSBackingStoreBuffered defer:NO];
    self = [super initWithWindow:window];
    if (self) {
        window.title = @"GUI Gopher";
        window.minSize = NSMakeSize(720, 460);
        self.client = [[GopherClient alloc] init];
        self.items = @[];
        self.history = [NSMutableArray array];
        self.bookmarks = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"GopherBookmarks"] mutableCopy] ?: [NSMutableArray array];
        self.historyIndex = -1;
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

    self.backButton = [self buttonWithTitle:@"‹" action:@selector(goBack:)];
    self.forwardButton = [self buttonWithTitle:@"›" action:@selector(goForward:)];
    self.backButton.font = [NSFont systemFontOfSize:22 weight:NSFontWeightRegular];
    self.forwardButton.font = [NSFont systemFontOfSize:22 weight:NSFontWeightRegular];
    self.backButton.enabled = NO;
    self.forwardButton.enabled = NO;
    [toolbar addSubview:self.backButton];
    [toolbar addSubview:self.forwardButton];
    self.reloadStopButton = [self buttonWithTitle:@"↻" action:@selector(reloadOrStop:)];
    self.reloadStopButton.font = [NSFont systemFontOfSize:17];
    self.reloadStopButton.toolTip = @"Reload";
    [toolbar addSubview:self.reloadStopButton];
    self.bookmarkButton = [self buttonWithTitle:@"☆" action:@selector(toggleBookmark:)];
    self.bookmarkButton.font = [NSFont systemFontOfSize:17];
    [toolbar addSubview:self.bookmarkButton];

    self.addressField = [[NSTextField alloc] initWithFrame:NSZeroRect];
    self.addressField.translatesAutoresizingMaskIntoConstraints = NO;
    self.addressField.placeholderString = @"Enter a Gopher address…";
    self.addressField.font = [NSFont systemFontOfSize:13];
    self.addressField.bezelStyle = NSTextFieldRoundedBezel;
    self.addressField.delegate = self;
    [toolbar addSubview:self.addressField];

    NSSplitView *splitView = [[NSSplitView alloc] initWithFrame:NSZeroRect];
    splitView.translatesAutoresizingMaskIntoConstraints = NO;
    splitView.vertical = YES;
    splitView.dividerStyle = NSSplitViewDividerStyleThin;
    [content addSubview:splitView];
    NSView *side = [[NSView alloc] initWithFrame:NSZeroRect];
    NSView *main = [[NSView alloc] initWithFrame:NSZeroRect];
    [splitView addSubview:side];
    [splitView addSubview:main];

    NSTableView *sidebar = [[NSTableView alloc] initWithFrame:NSZeroRect];
    sidebar.identifier = @"sidebar";
    NSTableColumn *sidebarColumn = [[NSTableColumn alloc] initWithIdentifier:@"sidebar"];
    [sidebar addTableColumn:sidebarColumn];
    sidebar.headerView = nil;
    sidebar.rowSizeStyle = NSTableViewRowSizeStyleDefault;
    sidebar.dataSource = self;
    sidebar.delegate = self;
    NSScrollView *sidebarScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    sidebarScroll.translatesAutoresizingMaskIntoConstraints = NO;
    sidebarScroll.hasVerticalScroller = YES;
    sidebarScroll.documentView = sidebar;
    [side addSubview:sidebarScroll];

    self.itemsTable = [[GopherItemsTableView alloc] initWithFrame:NSZeroRect];
    self.itemsTable.target = self;
    self.itemsTable.action = @selector(openSelectedItem:);
    NSTableColumn *iconColumn = [[NSTableColumn alloc] initWithIdentifier:@"icon"];
    iconColumn.width = 34; iconColumn.maxWidth = 34; iconColumn.minWidth = 34;
    iconColumn.resizingMask = NSTableColumnNoResizing;
    NSTableColumn *nameColumn = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    nameColumn.width = 420;
    nameColumn.minWidth = 200;
    nameColumn.resizingMask = NSTableColumnAutoresizingMask;
    NSTableColumn *descriptionColumn = [[NSTableColumn alloc] initWithIdentifier:@"description"];
    descriptionColumn.width = 160;
    descriptionColumn.minWidth = 130;
    descriptionColumn.resizingMask = NSTableColumnNoResizing;
    [self.itemsTable addTableColumn:iconColumn];
    [self.itemsTable addTableColumn:nameColumn];
    [self.itemsTable addTableColumn:descriptionColumn];
    self.itemsTable.headerView = nil;
    self.itemsTable.columnAutoresizingStyle = NSTableViewFirstColumnOnlyAutoresizingStyle;
    self.itemsTable.rowSizeStyle = NSTableViewRowSizeStyleLarge;
    self.itemsTable.usesAlternatingRowBackgroundColors = YES;
    self.itemsTable.dataSource = self;
    self.itemsTable.delegate = self;
    self.itemsTable.focusRingType = NSFocusRingTypeDefault;
    self.itemsTable.allowsMultipleSelection = NO;
    self.listScrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    self.listScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.listScrollView.hasVerticalScroller = YES;
    self.listScrollView.documentView = self.itemsTable;
    [main addSubview:self.listScrollView];

    self.readerView = [[NSTextView alloc] initWithFrame:NSZeroRect];
    self.readerView.editable = NO;
    self.readerView.selectable = YES;
    self.readerView.textContainerInset = NSMakeSize(32, 28);
    self.readerView.font = [NSFont userFixedPitchFontOfSize:13];
    self.readerScrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    self.readerScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.readerScrollView.hasVerticalScroller = YES;
    self.readerScrollView.documentView = self.readerView;
    self.readerScrollView.hidden = YES;
    [main addSubview:self.readerScrollView];

    self.welcomeLabel = [NSTextField labelWithString:@"A quieter corner of the internet."];
    self.welcomeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.welcomeLabel.font = [NSFont systemFontOfSize:22 weight:NSFontWeightMedium];
    self.welcomeLabel.textColor = NSColor.secondaryLabelColor;
    [main addSubview:self.welcomeLabel];
    self.statusLabel = [NSTextField labelWithString:@"Enter a Gopher address to begin"];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = [NSFont systemFontOfSize:11];
    self.statusLabel.textColor = NSColor.tertiaryLabelColor;
    [main addSubview:self.statusLabel];
    self.progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect];
    self.progressIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressIndicator.style = NSProgressIndicatorStyleSpinning;
    self.progressIndicator.controlSize = NSControlSizeSmall;
    self.progressIndicator.displayedWhenStopped = NO;
    [main addSubview:self.progressIndicator];
    self.retryButton = [self buttonWithTitle:@"Try Again" action:@selector(retryLastRequest:)];
    self.retryButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.retryButton.hidden = YES;
    [main addSubview:self.retryButton];

    [NSLayoutConstraint activateConstraints:@[
        [sidebarScroll.leadingAnchor constraintEqualToAnchor:side.leadingAnchor], [sidebarScroll.trailingAnchor constraintEqualToAnchor:side.trailingAnchor],
        [sidebarScroll.topAnchor constraintEqualToAnchor:side.topAnchor], [sidebarScroll.bottomAnchor constraintEqualToAnchor:side.bottomAnchor],
        [self.listScrollView.leadingAnchor constraintEqualToAnchor:main.leadingAnchor], [self.listScrollView.trailingAnchor constraintEqualToAnchor:main.trailingAnchor],
        [self.listScrollView.topAnchor constraintEqualToAnchor:main.topAnchor], [self.listScrollView.bottomAnchor constraintEqualToAnchor:main.bottomAnchor],
        [self.readerScrollView.leadingAnchor constraintEqualToAnchor:main.leadingAnchor], [self.readerScrollView.trailingAnchor constraintEqualToAnchor:main.trailingAnchor],
        [self.readerScrollView.topAnchor constraintEqualToAnchor:main.topAnchor], [self.readerScrollView.bottomAnchor constraintEqualToAnchor:main.bottomAnchor],
        [self.welcomeLabel.centerXAnchor constraintEqualToAnchor:main.centerXAnchor], [self.welcomeLabel.centerYAnchor constraintEqualToAnchor:main.centerYAnchor constant:-14],
        [self.statusLabel.centerXAnchor constraintEqualToAnchor:main.centerXAnchor], [self.statusLabel.topAnchor constraintEqualToAnchor:self.welcomeLabel.bottomAnchor constant:12],
        [self.progressIndicator.trailingAnchor constraintEqualToAnchor:self.statusLabel.leadingAnchor constant:-8], [self.progressIndicator.centerYAnchor constraintEqualToAnchor:self.statusLabel.centerYAnchor],
        [self.retryButton.centerXAnchor constraintEqualToAnchor:main.centerXAnchor], [self.retryButton.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:16],
        [toolbar.leadingAnchor constraintEqualToAnchor:content.leadingAnchor], [toolbar.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [toolbar.topAnchor constraintEqualToAnchor:content.topAnchor], [toolbar.heightAnchor constraintEqualToConstant:54],
        [self.backButton.leadingAnchor constraintEqualToAnchor:toolbar.leadingAnchor constant:14], [self.backButton.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor], [self.backButton.widthAnchor constraintEqualToConstant:30],
        [self.forwardButton.leadingAnchor constraintEqualToAnchor:self.backButton.trailingAnchor constant:4], [self.forwardButton.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor], [self.forwardButton.widthAnchor constraintEqualToConstant:30],
        [self.reloadStopButton.leadingAnchor constraintEqualToAnchor:self.forwardButton.trailingAnchor constant:4], [self.reloadStopButton.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor], [self.reloadStopButton.widthAnchor constraintEqualToConstant:30],
        [self.addressField.leadingAnchor constraintEqualToAnchor:self.reloadStopButton.trailingAnchor constant:10], [self.addressField.trailingAnchor constraintEqualToAnchor:self.bookmarkButton.leadingAnchor constant:-10],
        [self.addressField.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor], [self.addressField.heightAnchor constraintEqualToConstant:28],
        [self.bookmarkButton.trailingAnchor constraintEqualToAnchor:toolbar.trailingAnchor constant:-14], [self.bookmarkButton.centerYAnchor constraintEqualToAnchor:toolbar.centerYAnchor], [self.bookmarkButton.widthAnchor constraintEqualToConstant:30],
        [splitView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor], [splitView.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [splitView.topAnchor constraintEqualToAnchor:toolbar.bottomAnchor], [splitView.bottomAnchor constraintEqualToAnchor:content.bottomAnchor]
    ]];
    dispatch_async(dispatch_get_main_queue(), ^{ [splitView setPosition:220 ofDividerAtIndex:0]; });
}

- (NSButton *)buttonWithTitle:(NSString *)title action:(SEL)action {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.bezelStyle = NSBezelStyleTexturedRounded;
    return button;
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if (commandSelector == @selector(insertNewline:)) { [self openAddress:self.addressField.stringValue recordHistory:YES]; return YES; }
    return NO;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [tableView.identifier isEqualToString:@"sidebar"] ? (NSInteger)(2 + self.bookmarks.count + self.history.count) : self.items.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    if ([tableView.identifier isEqualToString:@"sidebar"]) {
        BOOL heading = row == 0 || row == (NSInteger)(self.bookmarks.count + 1);
        NSString *title = nil;
        if (row == 0) title = @"BOOKMARKS";
        else if (row <= (NSInteger)self.bookmarks.count) title = self.bookmarks[(NSUInteger)row - 1][@"title"];
        else if (row == (NSInteger)(self.bookmarks.count + 1)) title = @"HISTORY";
        else {
            NSUInteger historyOffset = (NSUInteger)(row - (NSInteger)self.bookmarks.count - 2);
            NSUInteger historyRow = self.history.count - 1 - historyOffset;
            title = [self titleForAddress:self.history[historyRow]];
        }
        NSTextField *label = [NSTextField labelWithString:title ?: @""];
        label.font = heading ? [NSFont systemFontOfSize:10 weight:NSFontWeightSemibold] : [NSFont systemFontOfSize:12];
        label.textColor = heading ? NSColor.tertiaryLabelColor : NSColor.labelColor;
        label.lineBreakMode = NSLineBreakByTruncatingTail;
        return label;
    }
    GopherItem *item = self.items[(NSUInteger)row];
    if ([column.identifier isEqualToString:@"icon"]) {
        NSImageView *imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 18, 18)];
        imageView.image = [NSImage imageWithSystemSymbolName:item.typeGlyph accessibilityDescription:item.title];
        imageView.contentTintColor = item.type == GopherItemTypeMenu ? NSColor.systemOrangeColor : NSColor.secondaryLabelColor;
        imageView.imageScaling = NSImageScaleProportionallyDown;
        return imageView;
    }
    NSTextField *label = [NSTextField labelWithString:item.title];
    if ([column.identifier isEqualToString:@"name"]) {
        label.maximumNumberOfLines = 0;
        label.usesSingleLineMode = NO;
        label.lineBreakMode = NSLineBreakByCharWrapping;
        label.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        label.toolTip = item.title;
    } else {
        label.font = [NSFont systemFontOfSize:12];
        label.textColor = NSColor.secondaryLabelColor;
        if (item.type == GopherItemTypeWebLink) label.stringValue = [NSURLComponents componentsWithString:item.externalURL].host ?: item.externalURL;
        else label.stringValue = [NSString stringWithFormat:@"%@:%ld", item.host, (long)item.port];
        label.toolTip = label.stringValue;
    }
    return label;
}

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row {
    return [tableView.identifier isEqualToString:@"sidebar"] ? nil : [[GopherItemRowView alloc] initWithFrame:NSZeroRect];
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    if ([tableView.identifier isEqualToString:@"sidebar"] || row < 0 || row >= (NSInteger)self.items.count) return 28;
    GopherItem *item = self.items[(NSUInteger)row];
    NSTableColumn *nameColumn = [tableView.tableColumns filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", @"name"]].firstObject;
    CGFloat availableWidth = MAX(100, nameColumn.width - 16);
    NSDictionary *attributes = @{NSFontAttributeName: [NSFont systemFontOfSize:13 weight:NSFontWeightMedium]};
    NSRect titleBounds = [item.title boundingRectWithSize:NSMakeSize(availableWidth, CGFLOAT_MAX)
                                                  options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                               attributes:attributes];
    return MAX(34, ceil(NSHeight(titleBounds)) + 14);
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSTableView *table = notification.object;
    if ([table.identifier isEqualToString:@"sidebar"]) {
        NSInteger row = table.selectedRow;
        if (row > 0 && row <= (NSInteger)self.bookmarks.count) {
            [self openAddress:self.bookmarks[(NSUInteger)row - 1][@"url"] recordHistory:YES];
        } else if (row > (NSInteger)(self.bookmarks.count + 1)) {
            NSUInteger historyOffset = (NSUInteger)(row - (NSInteger)self.bookmarks.count - 2);
            NSUInteger historyRow = self.history.count - 1 - historyOffset;
            [self openAddress:self.history[historyRow] recordHistory:YES];
        }
        [table deselectAll:nil];
        return;
    }
    NSInteger row = self.itemsTable.selectedRow;
    if (row >= 0 && row < (NSInteger)self.items.count) {
        GopherItem *item = self.items[(NSUInteger)row];
        self.statusLabel.stringValue = [NSString stringWithFormat:@"%@  ·  %@:%ld", item.title, item.host, (long)item.port];
    }
}

- (void)openSelectedItem:(id)sender {
    NSInteger row = self.itemsTable.clickedRow >= 0 ? self.itemsTable.clickedRow : self.itemsTable.selectedRow;
    if (row < 0 || row >= (NSInteger)self.items.count) return;
    GopherItem *item = self.items[(NSUInteger)row];
    if (item.type == GopherItemTypeInfo || item.type == GopherItemTypeUnknown) return;
    if (item.type == GopherItemTypeWebLink) {
        NSURLComponents *components = [NSURLComponents componentsWithString:item.externalURL];
        if ([components.scheme.lowercaseString isEqualToString:@"gopher"]) [self openAddress:item.externalURL recordHistory:YES];
        else if (components.URL) [[NSWorkspace sharedWorkspace] openURL:components.URL];
        return;
    }
    if (item.type == GopherItemTypeSearch) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Search this Gopher menu"; alert.informativeText = item.title;
        [alert addButtonWithTitle:@"Search"]; [alert addButtonWithTitle:@"Cancel"];
        NSTextField *queryField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 280, 24)];
        queryField.placeholderString = @"Search terms"; alert.accessoryView = queryField;
        if ([alert runModal] != NSAlertFirstButtonReturn || queryField.stringValue.length == 0) return;
        [self loadHost:item.host port:item.port selector:item.selector type:'7' query:queryField.stringValue url:nil recordHistory:YES];
        return;
    }
    unichar type = item.type == GopherItemTypeMenu ? '1' : item.type == GopherItemTypeText ? '0' : item.type == GopherItemTypeImage ? 'I' : '9';
    [self loadHost:item.host port:item.port selector:item.selector type:type query:nil url:nil recordHistory:YES];
}

- (void)goBack:(id)sender {
    if (self.historyIndex <= 0) return;
    self.historyIndex--; [self openAddress:self.history[(NSUInteger)self.historyIndex] recordHistory:NO];
}
- (void)goForward:(id)sender {
    if (self.historyIndex + 1 >= (NSInteger)self.history.count) return;
    self.historyIndex++; [self openAddress:self.history[(NSUInteger)self.historyIndex] recordHistory:NO];
}

- (void)openAddress:(NSString *)rawAddress recordHistory:(BOOL)recordHistory {
    NSString *address = [rawAddress stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (address.length == 0) return;
    if (![address.lowercaseString hasPrefix:@"gopher://"]) address = [@"gopher://" stringByAppendingString:address];
    NSURLComponents *components = [NSURLComponents componentsWithString:address];
    if (!components.host.length) { self.statusLabel.stringValue = @"Enter a valid Gopher host, such as gopher.floodgap.com"; return; }
    NSString *encodedPath = components.percentEncodedPath ?: @"/";
    NSString *path = [encodedPath stringByRemovingPercentEncoding] ?: encodedPath;
    unichar type = path.length > 1 ? [path characterAtIndex:1] : '1';
    NSString *selector = path.length > 1 ? [path substringFromIndex:2] : @"";
    NSString *query = components.percentEncodedQuery.length ? [components.percentEncodedQuery stringByRemovingPercentEncoding] : nil;
    NSInteger port = components.port ? components.port.integerValue : 70;
    [self loadHost:components.host port:port selector:selector type:type query:query url:address recordHistory:recordHistory];
}

- (void)loadHost:(NSString *)host port:(NSInteger)port selector:(NSString *)selector type:(unichar)type query:(NSString *)query url:(NSString *)url recordHistory:(BOOL)recordHistory {
    [self.currentRequestToken cancel];
    self.currentRequestToken = nil;
    self.currentHost = host; self.currentPort = port; self.currentSelector = selector; self.currentType = type;
    self.currentQuery = query;
    self.currentURL = url ?: [NSString stringWithFormat:@"gopher://%@:%ld/%C%@", host, (long)port, type, selector];
    self.addressField.stringValue = self.currentURL;
    self.bookmarkButton.title = [self isBookmarked:self.currentURL] ? @"★" : @"☆";
    self.welcomeLabel.stringValue = [NSString stringWithFormat:@"Connecting to %@…", host];
    self.welcomeLabel.hidden = NO;
    self.statusLabel.stringValue = [NSString stringWithFormat:@"Contacting Gopher server on port %ld", (long)port];
    self.retryButton.hidden = YES;
    self.listScrollView.hidden = YES; self.readerScrollView.hidden = YES;
    [self setLoading:YES];
    if (recordHistory) {
        while (self.history.count > (NSUInteger)(self.historyIndex + 1)) [self.history removeLastObject];
        [self.history addObject:self.currentURL]; self.historyIndex = (NSInteger)self.history.count - 1;
    }
    [self updateNavigationButtons];
    [self refreshSidebar];
    __block GopherRequestToken *requestToken = nil;
    requestToken = [self.client fetchHost:host port:port selector:selector query:(type == '7' ? query : nil) completion:^(NSData *data, NSError *error) {
        if (self.currentRequestToken != requestToken) return;
        self.currentRequestToken = nil;
        [self setLoading:NO];
        if (error) {
            self.statusLabel.stringValue = error.localizedDescription;
            self.welcomeLabel.stringValue = @"Couldn’t open this Gopher address.";
            self.welcomeLabel.hidden = NO;
            self.retryButton.hidden = NO;
            return;
        }
        if (type == '0') {
            NSString *text = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding] ?: [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
            self.welcomeLabel.hidden = YES;
            self.readerView.string = text; self.readerScrollView.hidden = NO;
            self.statusLabel.stringValue = [NSString stringWithFormat:@"Text document  ·  %@:%ld", host, (long)port];
            return;
        }
        if (type == '9' || type == 'g' || type == 'I') {
            NSSavePanel *panel = [NSSavePanel savePanel];
            panel.nameFieldStringValue = selector.lastPathComponent.length ? selector.lastPathComponent : @"gopher-download";
            if ([panel runModal] == NSModalResponseOK && panel.URL) {
                NSError *writeError = nil;
                if (![data writeToURL:panel.URL options:NSDataWritingAtomic error:&writeError]) self.statusLabel.stringValue = writeError.localizedDescription;
                else self.statusLabel.stringValue = @"Download complete";
            } else self.statusLabel.stringValue = @"Download cancelled";
            self.listScrollView.hidden = NO; return;
        }
        self.items = [GopherItem menuItemsFromData:data]; [self.itemsTable reloadData];
        self.listScrollView.hidden = NO; self.welcomeLabel.hidden = self.items.count > 0;
        self.welcomeLabel.stringValue = @"This menu is empty.";
        self.statusLabel.stringValue = [NSString stringWithFormat:@"%lu items  ·  %@:%ld", (unsigned long)self.items.count, host, (long)port];
    }];
    self.currentRequestToken = requestToken;
}

- (void)setLoading:(BOOL)loading {
    self.isLoading = loading;
    if (loading) [self.progressIndicator startAnimation:nil];
    else [self.progressIndicator stopAnimation:nil];
    self.reloadStopButton.title = loading ? @"×" : @"↻";
    self.reloadStopButton.toolTip = loading ? @"Stop loading" : @"Reload this Gopher menu";
}

- (void)reloadOrStop:(id)sender {
    if (self.isLoading) { [self stopLoading:sender]; return; }
    if (self.currentHost.length) [self loadHost:self.currentHost port:self.currentPort selector:self.currentSelector type:self.currentType query:self.currentQuery url:self.currentURL recordHistory:NO];
}

- (void)stopLoading:(id)sender {
    if (!self.isLoading) return;
    [self.currentRequestToken cancel];
    self.currentRequestToken = nil;
    [self setLoading:NO];
    self.listScrollView.hidden = YES;
    self.readerScrollView.hidden = YES;
    self.welcomeLabel.stringValue = @"Request stopped.";
    self.welcomeLabel.hidden = NO;
    self.statusLabel.stringValue = @"You can try again or enter another address.";
    self.retryButton.hidden = NO;
}

- (void)retryLastRequest:(id)sender {
    if (self.currentHost.length) [self loadHost:self.currentHost port:self.currentPort selector:self.currentSelector type:self.currentType query:self.currentQuery url:self.currentURL recordHistory:NO];
}

- (void)focusAddressBar:(id)sender {
    [self.window makeFirstResponder:self.addressField];
    [self.addressField selectText:nil];
}

- (void)updateNavigationButtons {
    self.backButton.enabled = self.historyIndex > 0;
    self.forwardButton.enabled = self.historyIndex + 1 < (NSInteger)self.history.count;
}

- (NSString *)titleForAddress:(NSString *)address {
    NSURLComponents *components = [NSURLComponents componentsWithString:address];
    NSString *lastPart = components.path.lastPathComponent;
    if (lastPart.length == 0 || [lastPart isEqualToString:@"1"]) return components.host ?: address;
    if (lastPart.length > 1) return [lastPart substringFromIndex:1];
    return components.host ?: address;
}

- (BOOL)isBookmarked:(NSString *)address {
    for (NSDictionary *bookmark in self.bookmarks) if ([bookmark[@"url"] isEqualToString:address]) return YES;
    return NO;
}

- (void)toggleBookmark:(id)sender {
    if (self.currentURL.length == 0) return;
    NSUInteger match = [self.bookmarks indexOfObjectPassingTest:^BOOL(NSDictionary *bookmark, NSUInteger idx, BOOL *stop) {
        return [bookmark[@"url"] isEqualToString:self.currentURL];
    }];
    if (match != NSNotFound) [self.bookmarks removeObjectAtIndex:match];
    else [self.bookmarks insertObject:@{@"title": [self titleForAddress:self.currentURL], @"url": self.currentURL} atIndex:0];
    [[NSUserDefaults standardUserDefaults] setObject:self.bookmarks forKey:@"GopherBookmarks"];
    self.bookmarkButton.title = [self isBookmarked:self.currentURL] ? @"★" : @"☆";
    [self refreshSidebar];
}

- (void)refreshSidebar {
    for (NSView *view in self.window.contentView.subviews) {
        if (![view isKindOfClass:NSSplitView.class]) continue;
        NSSplitView *split = (NSSplitView *)view;
        if (split.subviews.count == 0) continue;
        for (NSView *sideChild in split.subviews.firstObject.subviews) {
            if (![sideChild isKindOfClass:NSScrollView.class]) continue;
            NSScrollView *scroll = (NSScrollView *)sideChild;
            if ([scroll.documentView isKindOfClass:NSTableView.class]) [(NSTableView *)scroll.documentView reloadData];
        }
    }
}

@end

//
//  ToolCommandHistoryView.m
//  iTerm
//
//  Created by George Nachman on 1/15/14.
//
//

#import "ToolCommandHistoryView.h"
#import "CommandHistory.h"
#import "CommandHistoryEntry.h"
#import "iTermSearchField.h"
#import "NSDateFormatterExtras.h"
#import "PTYSession.h"

static const CGFloat kButtonHeight = 23;
static const CGFloat kMargin = 5;
static const CGFloat kHelpMargin = 5;

@implementation ToolCommandHistoryView {
    NSScrollView *scrollView_;
    NSTableView *tableView_;
    NSButton *clear_;
    BOOL shutdown_;
    NSArray *entries_;
    NSArray *filteredEntries_;
    iTermSearchField *searchField_;
    NSFont *boldFont_;
    NSButton *help_;
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        searchField_ = [[iTermSearchField alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, 1)];
        [searchField_ sizeToFit];
        searchField_.autoresizingMask = NSViewWidthSizable;
        searchField_.frame = NSMakeRect(0, 0, frame.size.width, searchField_.frame.size.height);
        [searchField_ setDelegate:self];
        [self addSubview:searchField_];

        help_ = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
        [help_ setBezelStyle:NSHelpButtonBezelStyle];
        [help_ setButtonType:NSMomentaryPushInButton];
        [help_ setBordered:YES];
        [help_ sizeToFit];
        help_.target = self;
        help_.action = @selector(help:);
        help_.title = @"";
        [help_ setAutoresizingMask:NSViewMinYMargin | NSViewMinXMargin];
        [self addSubview:help_];

        clear_ = [[NSButton alloc] initWithFrame:NSMakeRect(0, frame.size.height - kButtonHeight, frame.size.width, kButtonHeight)];
        [clear_ setButtonType:NSMomentaryPushInButton];
        [clear_ setTitle:@"Clear All"];
        [clear_ setTarget:self];
        [clear_ setAction:@selector(clear:)];
        [clear_ setBezelStyle:NSSmallSquareBezelStyle];
        [clear_ sizeToFit];
        [clear_ setAutoresizingMask:NSViewMinYMargin];
        [self addSubview:clear_];
        [clear_ release];
        
        scrollView_ = [[NSScrollView alloc] initWithFrame:NSMakeRect(0,
                                                                     searchField_.frame.size.height + kMargin,
                                                                     frame.size.width,
                                                                     frame.size.height - kButtonHeight - 2 * kMargin - searchField_.frame.size.height)];
        [scrollView_ setHasVerticalScroller:YES];
        [scrollView_ setHasHorizontalScroller:NO];
        NSSize contentSize = [self contentSize];
        [scrollView_ setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        
        tableView_ = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, contentSize.width, contentSize.height)];
        NSTableColumn *col;
        col = [[[NSTableColumn alloc] initWithIdentifier:@"commands"] autorelease];
        [col setEditable:NO];
        [tableView_ addTableColumn:col];
        [[col headerCell] setStringValue:@"Commands"];
        NSFont *theFont = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
        [[col dataCell] setFont:theFont];
        [tableView_ setRowHeight:[[[[NSLayoutManager alloc] init] autorelease] defaultLineHeightForFont:theFont]];
        [tableView_ setHeaderView:nil];
        [tableView_ setDataSource:self];
        [tableView_ setDelegate:self];

        [tableView_ setDoubleAction:@selector(doubleClickOnTableView:)];
        [tableView_ setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

        [searchField_ setArrowHandler:tableView_];
        
        [scrollView_ setDocumentView:tableView_];
        [self addSubview:scrollView_];
        
        [tableView_ sizeToFit];
        [tableView_ setColumnAutoresizingStyle:NSTableViewSequentialColumnAutoresizingStyle];
        
        // Save the bold version of the table's default font
        NSFontManager *fontManager = [NSFontManager sharedFontManager];
        NSFont *font = [[col dataCell] font];
        boldFont_ = [[fontManager fontWithFamily:font.familyName
                                          traits:NSBoldFontMask
                                          weight:0
                                            size:font.pointSize] retain];

        [self relayout];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(commandHistoryDidChange:)
                                                     name:kCommandHistoryDidChangeNotificationName
                                                   object:nil];
        [self updateCommands];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [tableView_ release];
    [scrollView_ release];
    [boldFont_ release];
    [super dealloc];
}

- (void)shutdown
{
    shutdown_ = YES;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSSize)contentSize
{
    NSSize size = [scrollView_ contentSize];
    size.height = [[tableView_ headerView] frame].size.height;
    size.height += [tableView_ numberOfRows] * ([tableView_ rowHeight] + [tableView_ intercellSpacing].height);
    return size;
}

- (void)relayout
{
    NSRect frame = self.frame;
    help_.frame = NSMakeRect(frame.size.width - help_.frame.size.width,
                             frame.size.height - help_.frame.size.height - ceil((clear_.frame.size.height - help_.frame.size.height) / 2),
                             help_.frame.size.width,
                             help_.frame.size.height);
    searchField_.frame = NSMakeRect(0, 0, frame.size.width, searchField_.frame.size.height);
    [clear_ setFrame:NSMakeRect(0,
                                frame.size.height - kButtonHeight,
                                frame.size.width - help_.frame.size.width - kHelpMargin,
                                kButtonHeight)];
    scrollView_.frame = NSMakeRect(0,
                                   searchField_.frame.size.height + kMargin,
                                   frame.size.width,
                                   frame.size.height - kButtonHeight - 2 * kMargin - searchField_.frame.size.height);
    NSSize contentSize = [self contentSize];
    [tableView_ setFrame:NSMakeRect(0, 0, contentSize.width, contentSize.height)];
}

- (BOOL)isFlipped
{
    return YES;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return filteredEntries_.count;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    CommandHistoryEntry *entry = filteredEntries_[rowIndex];
    if ([[aTableColumn identifier] isEqualToString:@"date"]) {
        // Date
        return [NSDateFormatter compactDateDifferenceStringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:entry.lastUsed]];
    } else {
        // Contents
        NSString* value = [entry.command stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
        ToolWrapper *wrapper = (ToolWrapper *)[[self superview] superview];
        if (entry.lastMark && [[wrapper.term currentSession] sessionID] == entry.lastMark.sessionID) {
            return [[[NSAttributedString alloc] initWithString:value
                                                   attributes:@{ NSFontAttributeName: boldFont_ }] autorelease];
        } else {
            return value;
        }
    }
}

- (CommandHistoryEntry *)selectedEntry {
    NSInteger row = [tableView_ selectedRow];
    if (row != -1) {
        return filteredEntries_[row];
    } else {
        return nil;
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    CommandHistoryEntry *entry = [self selectedEntry];

    if (entry.lastMark) {
        ToolWrapper *wrapper = (ToolWrapper *)[[self superview] superview];
        // Post a notification in case the captured output tool is observing us.
        [[NSNotificationCenter defaultCenter] postNotificationName:kPTYSessionCapturedOutputDidChange
                                                            object:nil];
        [[wrapper.term currentSession] scrollToMark:entry.lastMark];
    }
}

- (void)commandHistoryDidChange:(id)sender
{
    [self updateCommands];
}

- (void)updateCommands {
    [entries_ autorelease];
    ToolWrapper *wrapper = (ToolWrapper *)[[self superview] superview];
    VT100RemoteHost *host = [[wrapper.term currentSession] currentHost];
    NSArray *temp = [[CommandHistory sharedInstance] autocompleteSuggestionsWithPartialCommand:@""
                                                                                        onHost:host];
    NSArray *expanded = [[CommandHistory sharedInstance] entryArrayByExpandingAllUsesInEntryArray:temp];
    NSArray *reversed = [[expanded reverseObjectEnumerator] allObjects];
    entries_ = [reversed retain];
    [tableView_ reloadData];
    
    [self computeFilteredEntries];
    // Updating the table data causes the cursor to change into an arrow!
    [self performSelector:@selector(fixCursor) withObject:nil afterDelay:0];
    
    NSResponder *firstResponder = [[tableView_ window] firstResponder];
    if (firstResponder != tableView_) {
        [tableView_ scrollToEndOfDocument:nil];
    }
}

- (void)fixCursor
{
    if (shutdown_) {
        return;
    }
    ToolWrapper *wrapper = (ToolWrapper *)[[self superview] superview];
        [[[wrapper.term currentSession] textview] updateCursor:[[NSApplication sharedApplication] currentEvent]];
}

- (void)doubleClickOnTableView:(id)sender
{
    NSInteger selectedIndex = [tableView_ selectedRow];
    if (selectedIndex < 0) {
        return;
    }
    CommandHistoryEntry* entry = filteredEntries_[selectedIndex];
    ToolWrapper *wrapper = (ToolWrapper *)[[self superview] superview];
    NSString *text = entry.command;
    if (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask)) {
        if (entry.lastDirectory) {
            text = [@"cd " stringByAppendingString:entry.lastDirectory];
        } else {
            return;
        }
    }
    [[wrapper.term currentSession] insertText:text];
}

- (void)clear:(id)sender
{
    if (NSRunAlertPanel(@"Erase Command History",
                        @"Command history for all hosts will be erased. Continue?",
                        @"OK",
                        @"Cancel",
                        nil) == NSAlertDefaultReturn) {
        [[CommandHistory sharedInstance] eraseHistory];
    }
}

- (void)computeFilteredEntries
{
    [filteredEntries_ release];
    if (searchField_.stringValue.length == 0) {
        filteredEntries_ = [entries_ retain];
    } else {
        NSMutableArray *array = [NSMutableArray array];
        for (CommandHistoryEntry *entry in entries_) {
            if ([entry.command rangeOfString:searchField_.stringValue].location != NSNotFound) {
                [array addObject:entry];
            }
        }
        filteredEntries_ = [array retain];
    }
    [tableView_ reloadData];
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
    [self computeFilteredEntries];
}

- (CGFloat)minimumHeight
{
    return 88;
}

- (void)help:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://iterm2.com/shell_integration.html"]];
}

@end

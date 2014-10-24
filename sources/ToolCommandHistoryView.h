//
//  ToolCommandHistoryView.h
//  iTerm
//
//  Created by George Nachman on 1/15/14.
//
//

#import <Cocoa/Cocoa.h>
#import "ToolbeltView.h"

@class CommandHistoryEntry;

@interface ToolCommandHistoryView : NSView <
  ToolbeltTool,
  NSTableViewDataSource,
  NSTableViewDelegate,
  NSTextFieldDelegate>

- (id)initWithFrame:(NSRect)frame;
- (void)shutdown;
- (void)updateCommands;
- (CommandHistoryEntry *)selectedEntry;

@end

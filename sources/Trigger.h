//
//  Trigger.h
//  iTerm
//
//  Created by George Nachman on 9/23/11.
//

#import <Cocoa/Cocoa.h>

@class PTYSession;

extern NSString * const kTriggerRegexKey;
extern NSString * const kTriggerActionKey;
extern NSString * const kTriggerParameterKey;
extern NSString * const kTriggerPartialLineKey;

@interface Trigger : NSObject

@property (nonatomic, copy) NSString *regex;
@property (nonatomic, copy) NSString *action;
@property (nonatomic, copy) NSString *param;
@property (nonatomic, assign) BOOL partialLine;

+ (Trigger *)triggerFromDict:(NSDictionary *)dict;
- (NSString *)action;
// Subclasses should implement:
- (NSString *)title;
- (NSString *)paramPlaceholder;
// Returns true if this kind of action takes a parameter.
- (BOOL)takesParameter;
// Returns true if the parameter this action takes is a popupbutton.
- (BOOL)paramIsPopupButton;
// Returns a map from id(tag/represented object) -> NSString(title)
- (NSDictionary *)menuItemsForPoupupButton;
// Returns an array of NSDictionaries mapping NSNumber(tag) -> NSString(title)
- (NSArray *)groupedMenuItemsForPopupButton;

// Index of "tag" in menu; inverse of tagAtIndex.
// Deprecated
- (int)indexOfTag:(int)theTag;
// Tag at "index" in menu.
// Deprecated
- (int)tagAtIndex:(int)index;

// Index of represented object (usually a NSNumber tag, but could be something else)
- (int)indexForObject:(id)object;
// Represented object (usually a NSNumber tag, but could be something else) at an index.
- (id)objectAtIndex:(int)index;

// Utility that returns keys sorted by values for a tag/represented object dict
// (i.e., an element of groupedMenuItemsForPopupButton)
- (NSArray *)objectsSortedByValueInDict:(NSDictionary *)dict;

- (NSString *)paramWithBackreferencesReplacedWithValues:(NSArray *)values;
- (void)tryString:(NSString *)s
        inSession:(PTYSession *)aSession
      partialLine:(BOOL)partialLine
       lineNumber:(long long)lineNumber;

// Subclasses must override this. Return YES if it can fire again on this line.
- (BOOL)performActionWithValues:(NSArray *)values inSession:(PTYSession *)aSession onString:(NSString *)string atAbsoluteLineNumber:(long long)absoluteLineNumber;

- (NSComparisonResult)compareTitle:(Trigger *)other;

// If no parameter is present, the parameter index to select by default.
- (int)defaultIndex;

// Default value for a parameter of a popup. Trigger's implementation returns
// @0 but subclasses can override.
- (id)defaultPopupParameterObject;

// Called before a trigger window opens.
- (void)reloadData;

@end

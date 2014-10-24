//
//  TmuxControllerRegistry.h
//  iTerm
//
//  Created by George Nachman on 12/25/11.
//  Copyright (c) 2011 Georgetech. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TmuxController;

extern NSString *const kTmuxControllerRegistryDidChange;

@interface TmuxControllerRegistry : NSObject {
    NSMutableDictionary *controllers_;  // client -> controller
}

+ (TmuxControllerRegistry *)sharedInstance;
- (TmuxController *)controllerForClient:(NSString *)client;
- (void)setController:(TmuxController *)controller forClient:(NSString *)client;
- (int)numberOfClients;
- (NSString *)uniqueClientNameBasedOn:(NSString *)preferredName;
- (NSArray *)clientNames;

@end

//
//  NSArray+iTerm.m
//  iTerm
//
//  Created by George Nachman on 12/20/13.
//
//

#import "NSArray+iTerm.h"
#import "NSMutableAttributedString+iTerm.h"

@implementation NSArray (iTerm)

- (NSArray *)objectsOfClasses:(NSArray *)classes {
    NSMutableArray *result = [NSMutableArray array];
    for (NSObject *object in self) {
        for (Class validClass in classes) {
            if ([object isKindOfClass:validClass]) {
                [result addObject:object];
                break;
            }
        }
    }
    return result;
}

- (NSAttributedString *)attributedComponentsJoinedByAttributedString:(NSAttributedString *)joiner {
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];
    for (NSAttributedString *element in self) {
        [result appendAttributedString:element];
        [result appendAttributedString:joiner];
    }
    return result;
}

@end

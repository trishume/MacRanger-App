#import "iTermOpenQuicklyModel.h"
#import "iTermController.h"
#import "iTermLogoGenerator.h"
#import "iTermOpenQuicklyItem.h"
#import "PseudoTerminal.h"
#import "PTYSession+Scripting.h"
#import "VT100RemoteHost.h"

// It's nice for each of these to be unique so in degenerate cases (e.g., empty query) the detail
// uses the same feature for all items.
static const double kSessionNameMultiplier = 2;
static const double kSessionBadgeMultiplier = 3;
static const double kCommandMultiplier = 0.8;
static const double kDirectoryMultiplier = 0.9;
static const double kHostnameMultiplier = 1.2;
static const double kUsernameMultiplier = 0.5;
static const double kProfileNameMultiplier = 1;
static const double kUserDefinedVariableMultiplier = 1;

// Multipliers for profile items
static const double kProfileNameMultiplierForProfileItem = 0.1;

@implementation iTermOpenQuicklyModel

- (void)removeAllItems {
    [_items removeAllObjects];
}

// Returns an array of all sessions.
- (NSArray *)sessions {
    NSArray *terminals = [[iTermController sharedInstance] terminals];
    // sessions and scores are parallel.
    NSMutableArray *sessions = [NSMutableArray array];
    for (PseudoTerminal *term in terminals) {
        [sessions addObjectsFromArray:term.allSessions];
    }
    return sessions;
}

- (void)updateWithQuery:(NSString *)queryString {
    NSArray *sessions = [self sessions];

    queryString = [queryString lowercaseString];
    unichar *query = (unichar *)malloc(queryString.length * sizeof(unichar) + 1);
    [queryString getCharacters:query];
    query[queryString.length] = 0;

    NSMutableArray *items = [NSMutableArray array];
    for (PTYSession *session in sessions) {
        NSMutableArray *features = [NSMutableArray array];
        iTermOpenQuicklySessionItem *item = [[[iTermOpenQuicklySessionItem alloc] init] autorelease];
        item.logoGenerator.textColor = session.foregroundColor;
        item.logoGenerator.backgroundColor = session.backgroundColor;
        item.logoGenerator.tabColor = session.tabColor;
        item.logoGenerator.cursorColor = session.cursorColor;

        NSMutableAttributedString *attributedName = [[[NSMutableAttributedString alloc] init] autorelease];
        item.score = [self scoreForSession:session
                                     query:query
                                    length:queryString.length
                                  features:features
                            attributedName:attributedName];
        if (item.score > 0) {
            item.detail = [self detailForSession:session features:features];
            if (attributedName.length) {
                item.title = attributedName;
            } else {
                item.title = [_delegate openQuicklyModelDisplayStringForFeatureNamed:nil
                                                                               value:session.name
                                                                  highlightedIndexes:nil];
            }

            item.identifier = session.uniqueID;
            [items addObject:item];
        }
    }

    BOOL haveCurrentWindow = [[iTermController sharedInstance] currentTerminal] != nil;
    for (Profile *profile in [[ProfileModel sharedInstance] bookmarks]) {
        iTermOpenQuicklyProfileItem *item = [[[iTermOpenQuicklyProfileItem alloc] init] autorelease];
        item.score = [self scoreForProfile:profile query:query length:queryString.length];
        if (item.score > 0) {
            NSString *theValue;
            if (!haveCurrentWindow || [profile[KEY_PREVENT_TAB] boolValue]) {
                theValue = @"Create a new window with this profile";
            } else {
                theValue = @"Create a new tab with this profile";
            }
            item.detail = [_delegate openQuicklyModelDisplayStringForFeatureNamed:nil
                                                                            value:theValue
                                                               highlightedIndexes:nil];
            item.title = profile[KEY_NAME];
            item.identifier = profile[KEY_GUID];
            [items addObject:item];
        }
    }

    // Sort from highest to lowest score.
    [items sortUsingComparator:^NSComparisonResult(iTermOpenQuicklyItem *obj1,
                                                   iTermOpenQuicklyItem *obj2) {
        return [@(obj2.score) compare:@(obj1.score)];
    }];

    // To avoid performance issues, only keep the 100 best.
    static const int kMaxItems = 100;
    if (items.count > kMaxItems) {
        [items removeObjectsInRange:NSMakeRange(kMaxItems, items.count - kMaxItems)];
    }

    // Replace self.items with new items.
    self.items = items;
    free(query);
}

- (double)scoreForProfile:(Profile *)profile query:(unichar *)query length:(int)length {
    double score = [self scoreForQuery:query
                             documents:@[ profile[KEY_NAME] ]
                            multiplier:kProfileNameMultiplierForProfileItem
                                  name:nil
                              features:nil
                                 limit:2 * kProfileNameMultiplierForProfileItem];
    if (score > 0 &&
        [[[ProfileModel sharedInstance] defaultBookmark][KEY_GUID] isEqualToString:profile[KEY_GUID]]) {
        // Make the default profile always be the highest-scored profile if it matches the query.
        score += 0.2;
    }
    return score;
}

// Returns the score for a session.
// session: The session to score against a query
// query: The search query (null terminate)
// length: The length of the query array
// features: An array that will be populated with tuples of (detail, score).
//   The detail element is a suitable-for-display NSAttributedString*s
//   describing features that matched the query, while the score element is the
//   score assigned to that feature.
// attributedName: The session's name with matching characters highlighted
//   (suitable for display) will be appended to this NSMutableAttributedString.
- (double)scoreForSession:(PTYSession *)session
                    query:(unichar *)query
                   length:(int)length
                 features:(NSMutableArray *)features
           attributedName:(NSMutableAttributedString *)attributedName {
    double score = 0;
    double maxScorePerFeature = 2 + length / 4;
    if (session.name) {
        NSMutableArray *nameFeature = [NSMutableArray array];
        score += [self scoreForQuery:query
                           documents:@[ session.name ]
                          multiplier:kSessionNameMultiplier
                                name:nil
                            features:nameFeature
                               limit:maxScorePerFeature];
        if (nameFeature.count) {
            [attributedName appendAttributedString:nameFeature[0][0]];
        }
    }

    if (session.badgeLabel) {
        score += [self scoreForQuery:query
                           documents:@[ session.badgeLabel ]
                          multiplier:kSessionBadgeMultiplier
                                name:@"Badge"
                            features:features
                               limit:maxScorePerFeature];
    }

    score += [self scoreForQuery:query
                       documents:session.commands
                      multiplier:kCommandMultiplier
                            name:@"Command"
                        features:features
                           limit:maxScorePerFeature];

    score += [self scoreForQuery:query
                       documents:session.directories
                      multiplier:kDirectoryMultiplier
                            name:@"Directory"
                        features:features
                           limit:maxScorePerFeature];

    score += [self scoreForQuery:query
                       documents:[self hostnamesInHosts:session.hosts]
                      multiplier:kHostnameMultiplier
                            name:@"Host"
                        features:features
                           limit:maxScorePerFeature];

    score += [self scoreForQuery:query
                       documents:[self usernamesInHosts:session.hosts]
                      multiplier:kUsernameMultiplier
                            name:@"User"
                        features:features
                           limit:maxScorePerFeature];

    score += [self scoreForQuery:query
                       documents:@[ session.profile[KEY_NAME] ?: @"" ]
                      multiplier:kProfileNameMultiplier
                            name:@"Profile"
                        features:features
                           limit:maxScorePerFeature];

    for (NSString *var in session.variables) {
        NSString *const kUserPrefix = @"user.";
        if ([var hasPrefix:kUserPrefix]) {
            score += [self scoreForQuery:query
                               documents:@[ session.variables[var] ]
                              multiplier:kUserDefinedVariableMultiplier
                                    name:[var substringFromIndex:[kUserPrefix length]]
                                features:features
                                   limit:maxScorePerFeature];
        }
    }

    // TODO: add a bonus for:
    // Doing lots of typing in a session
    // Being newly created
    // Recency of use

    return score;
}

// Given an array of features which are a tuple of (detail, score), return the
// detail for the highest scoring one.
- (NSAttributedString *)detailForSession:(PTYSession *)session features:(NSArray *)features {
    NSArray *sorted = [features sortedArrayUsingComparator:^NSComparisonResult(NSArray *tuple1, NSArray *tuple2) {
        NSNumber *score1 = tuple1[1];
        NSNumber *score2 = tuple2[1];
        return [score1 compare:score2];
    }];
    return [sorted lastObject][0];
}

// Returns the total score for a query matching an array of documents. This
// should be called once per feature.
// query: The user-entered query
// documents: An array of NSString*s to search, ordered from least recent to
//   most recent (less recent documents have their scores heavily discounted)
// multiplier: The sum of the documents' scores is multiplied by this value.
// name: The display name of the current feature.
// features: The highest-scoring document will have an NSAttributedString added
//   to this array describing the match, suitable for display.
// limit: Upper bound for the returned score.
- (double)scoreForQuery:(unichar *)query
              documents:(NSArray *)documents
             multiplier:(double)multipler
                   name:(NSString *)name
               features:(NSMutableArray *)features
                  limit:(double)limit {
    if (multipler == 0) {
        // Feature is disabled. In the future, we might let users tweak multipliers.
        return 0;
    }
    double score = 0;
    double highestValue = 0;
    NSString *bestFeature = nil;
    NSIndexSet *bestIndexSet = nil;
    int n = documents.count;
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    for (NSString *document in documents) {
        [indexSet removeAllIndexes];
        double value = [self qualityOfMatchBetweenQuery:query
                                              andString:[document lowercaseString]
                                               indexSet:indexSet];

        // Discount older documents (which appear at the beginning of the list)
        value /= n;
        n--;

        if (value > highestValue) {
            highestValue = value;
            bestFeature = document;
            bestIndexSet = [[indexSet copy] autorelease];
        }
        score += value * multipler;
        if (score > limit) {
            break;
        }
    }

    if (bestFeature && features) {
        id displayString = [_delegate openQuicklyModelDisplayStringForFeatureNamed:name
                                                                             value:bestFeature
                                                                highlightedIndexes:bestIndexSet];
        [features addObject:@[ displayString, @(score) ]];
    }

    return MIN(limit, score);
}

// Returns a value between 0 and 1 for how well a query matches a document.
// The passed-in indexSet will be populated with indices into documentString
// that were found to match query.
// The current implementation returns:
//   1.0 if query is a prefix of document.
//   0.5 if query is a subsequence of document
//   0.0 otherwise
- (double)qualityOfMatchBetweenQuery:(unichar *)query
                           andString:(NSString *)documentString
                            indexSet:(NSMutableIndexSet *)indexSet {
    unichar *document = (unichar *)malloc(documentString.length * sizeof(unichar) + 1);
    [documentString getCharacters:document];
    document[documentString.length] = 0;
    int q = 0;
    int d = 0;
    while (query[q] && document[d]) {
        if (document[d] == query[q]) {
            [indexSet addIndex:d];
            ++q;
        }
        ++d;
    }
    double score;
    if (query[q]) {
        score = 0;
    } else if (q == d) {
        // Is a prefix
        score = 1;
    } else {
        score = 0.5;
    }
    free(document);
    return score;
}

// Returns an array of hostnames from an array of VT100RemoteHost*s
- (NSArray *)hostnamesInHosts:(NSArray *)hosts {
    NSMutableArray *names = [NSMutableArray array];
    for (VT100RemoteHost *host in hosts) {
        [names addObject:host.hostname];
    }
    return names;
}

// Returns an array of usernames from an array of VT100RemoteHost*s
- (NSArray *)usernamesInHosts:(NSArray *)hosts {
    NSMutableArray *names = [NSMutableArray array];
    for (VT100RemoteHost *host in hosts) {
        [names addObject:host.username];
    }
    return names;
}

- (id)objectAtIndex:(NSInteger)index {
    iTermOpenQuicklyItem *item = _items[index];
    if ([item isKindOfClass:[iTermOpenQuicklyProfileItem class]]) {
        return [[ProfileModel sharedInstance] bookmarkWithGuid:item.identifier];
    } else if ([item isKindOfClass:[iTermOpenQuicklySessionItem class]]) {
        NSString *sessionId = item.identifier;
        for (PTYSession *session in [self sessions]) {
            if ([session.uniqueID isEqualTo:sessionId]) {
                return session;
            }
        }
    }
    return nil;
}

@end

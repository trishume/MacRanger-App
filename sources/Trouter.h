// -*- mode:objc -*-
/*
 **  Trouter.h
 **
 **  Copyright (c) 2011
 **
 **  Author: Jack Chen (chendo)
 **
 **  Project: iTerm
 **
 **  Description: Semantic History
 **
 **  This program is free software; you can redistribute it and/or modify
 **  it under the terms of the GNU General Public License as published by
 **  the Free Software Foundation; either version 2 of the License, or
 **  (at your option) any later version.
 **
 **  This program is distributed in the hope that it will be useful,
 **  but WITHOUT ANY WARRANTY; without even the implied warranty of
 **  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 **  GNU General Public License for more details.
 **
 **  You should have received a copy of the GNU General Public License
 **  along with this program; if not, write to the Free Software
 **  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#import <Cocoa/Cocoa.h>

// Keys for substitutions of openPath:workingDirectory:substitutions:.
extern NSString *const kSemanticHistoryPathSubstitutionKey;
extern NSString *const kSemanticHistoryPrefixSubstitutionKey;
extern NSString *const kSemanticHistorySuffixSubstitutionKey;
extern NSString *const kSemanticHistoryWorkingDirectorySubstitutionKey;

@protocol TrouterDelegate
- (void)trouterLaunchCoprocessWithCommand:(NSString *)command;
@end

@interface Trouter : NSObject {
    NSDictionary *prefs_;
    NSFileManager *fileManager;
	id<TrouterDelegate> delegate_;
}

@property (nonatomic, copy) NSDictionary *prefs;
@property (nonatomic, assign) id<TrouterDelegate> delegate;
@property (nonatomic, readonly) BOOL activatesOnAnyString;  // Doesn't have to be a real file?

- (Trouter*)init;
- (void)dealloc;
- (BOOL)isTextFile:(NSString *)path;
- (BOOL)file:(NSString *)path conformsToUTI:(NSString *)uti;
- (BOOL)isDirectory:(NSString *)path;
- (NSFileManager *)fileManager;
- (NSString *)getFullPath:(NSString *)path
         workingDirectory:(NSString *)workingDirectory
               lineNumber:(NSString **)lineNumber;
- (BOOL)openFileInEditor:(NSString *) path lineNumber:(NSString *)lineNumber;
- (BOOL)canOpenPath:(NSString *)path workingDirectory:(NSString *)workingDirectory;
- (BOOL)openPath:(NSString *)path
        workingDirectory:(NSString *)workingDirectory
           substitutions:(NSDictionary *)substitutions;

// Do a brute force search by putting together suffixes of beforeString with prefixes of afterString
// to find an existing file in |workingDirectory|. |charsSTakenFromPrefixPtr| will be filled in with
// the number of characters from beforeString used.
- (NSString *)pathOfExistingFileFoundWithPrefix:(NSString *)beforeStringIn
                                         suffix:(NSString *)afterStringIn
                               workingDirectory:(NSString *)workingDirectory
                           charsTakenFromPrefix:(int *)charsTakenFromPrefixPtr;

@end

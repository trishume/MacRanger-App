// -*- mode:objc -*-
// $Id: PTYScrollView.h,v 1.6 2004-03-14 06:05:38 ujwal Exp $
/*
 **  PTYScrollView.h
 **
 **  Copyright (c) 2002, 2003
 **
 **  Author: Fabian, Ujwal S. Setlur
 **      Initial code by Kiichi Kusama
 **
 **  Project: iTerm
 **
 **  Description: NSScrollView subclass. Handles user scroll detection.
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

@interface PTYScroller : NSScroller

@property(nonatomic, assign) BOOL userScroll;

+ (BOOL)isCompatibleWithOverlayScrollers;
- (void)mouseDown: (NSEvent *)theEvent;
- (void)trackScrollButtons:(NSEvent *)theEvent;
- (void)trackKnob:(NSEvent *)theEvent;

@end

@interface PTYScrollView : NSScrollView

- (id)initWithFrame:(NSRect)frame hasVerticalScroller:(BOOL)hasVerticalScroller;
- (void)scrollWheel:(NSEvent *)theEvent;
- (void)detectUserScroll;
- (BOOL)isLegacyScroller;


@end

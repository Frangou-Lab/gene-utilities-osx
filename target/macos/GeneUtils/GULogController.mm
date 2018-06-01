/*
 * Copyright 2018 Frangou Lab
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "GULogController.h"
#import "GUUtils.h"

#include <string>

#include <libgene/log/Logger.hpp>

static GUILogController *_GUILogController_logControllerSharedInstance;

@implementation GUILogController
{
    IBOutlet NSTextView *_textView;
    IBOutlet NSScrollView *_logScrollView;
    NSDateFormatter *_timeFormatter;
    NSTimer *_timer;
}

+ (instancetype)sharedInstance
{
    return _GUILogController_logControllerSharedInstance;
}

- (void)viewDidLoad
{
    _timeFormatter = [NSDateFormatter new];
    _timeFormatter.dateStyle = NSDateFormatterNoStyle;
    _timeFormatter.timeStyle = NSDateFormatterMediumStyle;
    _timer = [NSTimer new];
    _GUILogController_logControllerSharedInstance = self;
    
    gene::logger::logLambda = [](std::string message) {
        [GUILogController printfWasCalledWithString:[NSString stringWithUTF8String:message.c_str()]];
    };
    
    [super viewDidLoad];
}

- (void)appendStringToLogViewWithTimestamp:(NSString *)str
{
    NSString* timestamp = [NSString stringWithFormat:@"[%@]", [_timeFormatter stringFromDate:[NSDate date]]];
    NSString* appendString = nil;
    if ([str hasSuffix:@"\n"])
        appendString = [NSString stringWithFormat:@"%@ %@", timestamp, str];
    else
        appendString = [NSString stringWithFormat:@"%@ %@\n", timestamp, str];
    
    if (_textView.textStorage.mutableString.length == 1)
        [_textView.textStorage replaceCharactersInRange:NSMakeRange(0, 1) withString:appendString];
    else
        [_textView.textStorage.mutableString appendString:appendString];

    [_textView setNeedsDisplay:YES];
    [_textView displayIfNeeded];
}

- (void)scrollLogViewDown
{
    // Scroll log view to the latest line
    if ([_logScrollView hasVerticalScroller])
        _logScrollView.verticalScroller.floatValue = MAXFLOAT;

    [_logScrollView.contentView scrollToPoint:NSMakePoint(0, ((NSView*)_logScrollView.documentView).frame.size.height - _logScrollView.contentSize.height)];
}

+ (void)printfWasCalledWithString:(NSString *)str
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [GUILogController.sharedInstance appendStringToLogViewWithTimestamp:str];
        [GUILogController.sharedInstance scrollLogViewDown];
    });
}

@end

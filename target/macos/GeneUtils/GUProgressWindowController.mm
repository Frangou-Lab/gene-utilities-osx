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

#import "GUProgressWindowController.h"

#include <atomic>

const double kTimeUpdateInterval = 30.0;

@implementation GUProgressWindowController
{
    IBOutlet NSProgressIndicator *progressBar_;
    IBOutlet NSTextField *percentTextField_;
    IBOutlet NSTextField *taskStatusTextField_;
    IBOutlet NSTextField *currentStatusTextField_;
    IBOutlet NSButton *cancelButton_;
    IBOutlet NSLayoutConstraint *cancelButtonRightConstraint_;
    IBOutlet NSLayoutConstraint *progressBarWidthConstraint_;
    IBOutlet NSLayoutConstraint *progressBarHeightConstraint_;
    NSTimer *remaining_timer_;
    NSString *remaining_time_string_;
    double last_progress_value_;
    std::atomic<bool> cancel_clicked_;
    GUProgressWindowMode mode_;
}

@synthesize timeEstimationEnabled = timeEstimationEnabled_;

- (void)windowDidLoad
{
    [super windowDidLoad];
    [self.window setAlphaValue:1.0];
    //Set backgroundColor to clearColor
    self.window.backgroundColor = [NSColor colorWithRed:0.921 green:0.921 blue:0.921 alpha:0.88];
    // Turn off opacity so that the parts of the window that are not drawn into are transparent.
    [self.window setOpaque:NO];

    [progressBar_ setWantsLayer:YES];

    // CALayer

    // [progressBar_.layer setFilters:nil];

    [self changeProgressWindowMode:mode_];
    _numberOfFiles = 0;
    taskStatusTextField_.hidden = (_numberOfFiles == 0);
    timeEstimationEnabled_ = true;
    [progressBar_ setUsesThreadedAnimation:YES];
    [progressBar_ startAnimation:nil];
}

- (void)setTimeEstimationEnabled:(bool)timeEstimationEnabled
{
    timeEstimationEnabled_ = timeEstimationEnabled;

    if (! timeEstimationEnabled)
    {
        remaining_time_string_ = @"";
        [self setProgress:progressBar_.doubleValue];
    }
}

- (void)updateRemainingTimeString
{
    if (! timeEstimationEnabled_)
        return;

    double deltaProgress = progressBar_.doubleValue - last_progress_value_;
    last_progress_value_ = progressBar_.doubleValue;

    double percentPerSecond = deltaProgress/kTimeUpdateInterval;
    double secondsRemaining = (100.0 - progressBar_.doubleValue)/percentPerSecond;

    long hours = lround(floor(secondsRemaining / 3600.)) % 100;
    long minutes = lround(floor(secondsRemaining / 60.)) % 60;

    if (hours == 1) {
        remaining_time_string_ = [NSString stringWithFormat:@"(%li hour %li minutes remaining)",
                                  hours, minutes];
    } else if (hours > 1) {
        remaining_time_string_ = [NSString stringWithFormat:@"(%li hours %li minutes remaining)",
                                  hours, minutes];
    } else {
        if (minutes > 1)
            remaining_time_string_ = [NSString stringWithFormat:@"(%li minutes remaining)", minutes];
        else
            remaining_time_string_ = @"(less than a minute remaining)";
    }
}

- (void)showProgessWindowWithMode:(GUProgressWindowMode)mode
{
    mode_ = mode;
    remaining_time_string_ = @"";
    last_progress_value_ = 0.0;
    cancel_clicked_ = false;
    _numberOfFiles = 1;
    cancelButton_.state = NSControlStateValueOff;

    [self setProgress:0];
    remaining_timer_ = [NSTimer scheduledTimerWithTimeInterval:kTimeUpdateInterval
                                                        target:self
                                                      selector:@selector(updateRemainingTimeString)
                                                      userInfo:nil
                                                       repeats:YES];
    [self changeProgressWindowMode:mode_];
    taskStatusTextField_.hidden = (mode_ != GUProgressWindowMode::DeterminateMultipleJobs);
    [[NSApp mainWindow] beginSheet:self.window completionHandler:nil];
    [self.window makeKeyAndOrderFront:nil];
}

- (IBAction)cancelTaskButtonClicked:(id)sender
{
    [self cancelCurrentTask];
    [remaining_timer_ invalidate];
    remaining_time_string_ = @"";
    currentStatusTextField_.stringValue = @"Cancelling";
}

- (void)changeProgressWindowMode:(GUProgressWindowMode)mode
{
    switch (mode) {
        case GUProgressWindowMode::Indeterminate:
            [self.window setFrame:NSMakeRect(self.window.frame.origin.x, self.window.frame.origin.y, 200.0, 134.0)
                          display:YES];
            progressBarWidthConstraint_.constant = 50.0;
            progressBarHeightConstraint_.constant = 50.0;
            cancelButtonRightConstraint_.constant = 65.0;
            break;

        case GUProgressWindowMode::Determinate:
        case GUProgressWindowMode::DeterminateMultipleJobs:
            [self.window setFrame:NSMakeRect(self.window.frame.origin.x, self.window.frame.origin.y, 424.0, 103.0)
                          display:YES];
            progressBarWidthConstraint_.constant = 384.0;
            progressBarHeightConstraint_.constant = 18.0;
            cancelButtonRightConstraint_.constant = 20.0;
            break;
    }

    progressBar_.indeterminate = (mode == GUProgressWindowMode::Indeterminate);
    percentTextField_.hidden = progressBar_.indeterminate;
    cancelButton_.state = NSControlStateValueOff;
    progressBar_.style = (progressBar_.indeterminate ? NSProgressIndicatorSpinningStyle : NSProgressIndicatorBarStyle);
}

- (void)cancelCurrentTask
{
    cancel_clicked_ = true;
}

- (bool)setProgress:(float)percent
{
    dispatch_async(dispatch_get_main_queue(), ^{
        progressBar_.doubleValue = percent;
        percentTextField_.stringValue = [NSString stringWithFormat:@"%.f%% %@",
                                         percent, remaining_time_string_];
    });
    return cancel_clicked_;
}

- (void)setNumberOfFiles:(NSInteger)number
{
    taskStatusTextField_.hidden = (number == 0);
    _numberOfFiles = number;
    taskStatusTextField_.stringValue = [NSString stringWithFormat:@"Job 1 of %ld", _numberOfFiles];
}

- (void)setNumberOfCurrentFile:(NSInteger)currentNumber
{
    taskStatusTextField_.stringValue = [NSString stringWithFormat:@"Job %ld of %ld", currentNumber,
                                        _numberOfFiles];
    last_progress_value_ = 0.0;
    progressBar_.doubleValue = 0.0;
    remaining_time_string_ = @"";

    [remaining_timer_ invalidate];
    remaining_timer_ = [NSTimer scheduledTimerWithTimeInterval:kTimeUpdateInterval
                                                        target:self
                                                      selector:@selector(updateRemainingTimeString)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)resetController
{
    cancel_clicked_ = false;
    _numberOfFiles = 1;
    last_progress_value_ = 0.0;
}

- (void)setStatus:(NSString *)statusText
{
    currentStatusTextField_.hidden = (statusText.length == 0);
    currentStatusTextField_.stringValue = statusText;
}

- (bool)cancelWasClicked
{
    return cancel_clicked_;
}

- (bool)dismissProgressViewController
{
    [remaining_timer_ invalidate];
    progressBar_.doubleValue = 0.0;
    [progressBar_ stopAnimation:nil];
    remaining_time_string_ = @"";
    percentTextField_.stringValue = @"0% ";
    currentStatusTextField_.stringValue = @"";
    last_progress_value_ = 0.0;
    cancelButton_.state = 0;
    [NSApp stopModal];
    [self close];
    return cancel_clicked_;
}

@end


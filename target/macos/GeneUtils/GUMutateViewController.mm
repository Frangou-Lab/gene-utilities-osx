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

#import "SequenceFileObj.h"
#import "CommandLineFlagsObj.h"
#import "GUMutateViewController.h"
#import "Mutator.h"
#import "GUProgressWindowController.h"
#import "Utils.h"
#import "GUUtils.h"
#import "GenomicCsvFileObj.h"
#import "GenomicTsvFileObj.h"

#include <libgene/log/Logger.hpp>

@implementation GUMutateViewController
{
    IBOutlet NSPathControl *_referenceFilePathControl;
    IBOutlet NSPathControl *_translationReferenceFilePathControl;
    IBOutlet NSPathControl *_mutationDataPathControl;
    IBOutlet NSButton *_mutateButton;
    GUProgressWindowController *_progressWindow;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    _progressWindow = [[GUProgressWindowController alloc] initWithWindowNibName:@"GUProgressWindowController"];
}

- (IBAction)_referenceFilePathControlClicked:(NSPathControl *)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setDirectoryURL:sender.clickedPathItem.URL];
    [openPanel setAllowedFileTypes:[[GenomicCsvFileObj.extensions allObjects]
                                    arrayByAddingObjectsFromArray:[GenomicTsvFileObj.extensions
                                                                   allObjects]]];
    
    if ([openPanel runModal] == NSModalResponseOK) {
        [_referenceFilePathControl setURL:openPanel.URL];
        _translationReferenceFilePathControl.enabled = YES;
    }
}

- (IBAction)_translationReferenceFilePathControlClicked:(NSPathControl *)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setDirectoryURL:sender.clickedPathItem.URL];
    [openPanel setAllowedFileTypes:[[GenomicCsvFileObj.extensions allObjects]
                                    arrayByAddingObjectsFromArray:[GenomicTsvFileObj.extensions
                                                                   allObjects]]];
    
    if ([openPanel runModal] == NSModalResponseOK) {
        [_translationReferenceFilePathControl setURL:openPanel.URL];
        _mutationDataPathControl.enabled = YES;
    }
}

- (IBAction)_mutationDataPathControlClicked:(NSPathControl *)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setDirectoryURL:sender.clickedPathItem.URL];
    [openPanel setAllowedFileTypes:[[GenomicCsvFileObj.extensions allObjects]
                                    arrayByAddingObjectsFromArray:[GenomicTsvFileObj.extensions
                                                                   allObjects]]];
    
    if ([openPanel runModal] == NSModalResponseOK) {
        [_mutationDataPathControl setURL:openPanel.URL];
        _mutateButton.enabled = YES;
    }
}

- (IBAction)_mutateButtonClicked:(id)sender
{
    CommandLineFlagsObj* flags = [CommandLineFlagsObj new];
    flags.verbose = YES;
    
    __block Mutator *mut = [[Mutator alloc] initWithInput:_mutationDataPathControl.URL.path.UTF8String
                                        reference:_referenceFilePathControl.URL.path.UTF8String
                                   transReference:_translationReferenceFilePathControl.URL.path.UTF8String
                                            flags:flags];
    if (!mut) {
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [_progressWindow showProgessWindowWithMode:GUProgressWindowMode::Determinate];
        });
        
        __block BOOL code = [mut process];
        mut = nil;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL wasCancelled = [_progressWindow dismissProgressViewController];
            [_progressWindow resetController];
            
            if (wasCancelled)
            {
                PrintfLog("CANCELLED");
                return;
            }
            
            if (code) {
                [GUUtils showAlertWithMessage:@"Mutate has completed successfully" andImageNamed:@"NSError"];
            }
            else {
                [GUUtils showAlertWithMessage:@"An error has occurred. See log for deatails" andImageNamed:@"NSError"];
            }
        });
    });
}

- (void)operationDidCancel
{
    [_progressWindow dismissProgressViewController];
}

- (BOOL)updateProgressTo:(float)percent
{
    return [_progressWindow setProgress:percent];
}

@end

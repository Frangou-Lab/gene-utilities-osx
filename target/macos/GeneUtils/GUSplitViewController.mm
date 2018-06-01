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

#import "GUSplitViewController.h"

#include "Splitter.hpp"
#include <libgene/log/Logger.hpp>
#include <libgene/def/Extensions.hpp>
#include <libgene/file/sequence/SequenceFile.hpp>

#import "GUFileFormatBoxController.h"
#import "GUProgressWindowController.h"
#import "GUUtils.h"

@implementation GUSplitViewController
{
    IBOutlet NSPathControl *_inputFilePathControl;
    IBOutlet NSButton *_splitButton;
    IBOutlet NSView *_fileFormatBoxView;
    GUFileFormatBoxController *p_fileFormatBox;
    IBOutlet NSPathControl *_outputFilePathControl;
    IBOutlet NSPopUpButton *_unitOfSeparationButton;
    IBOutlet NSTextField *_numberOfUnitsTextField;
    GUProgressWindowController *_progressWindow;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    p_fileFormatBox = [[GUFileFormatBoxController alloc] initWithNibName:@"GUFileFormatBox" bundle:nil];
    [_fileFormatBoxView addSubview:p_fileFormatBox.view];
    p_fileFormatBox.delegate = self;
    p_fileFormatBox.dataSource = self;
    p_fileFormatBox.inputOutputShouldntMatch = NO;
    [p_fileFormatBox updateData];
    _progressWindow = [[GUProgressWindowController alloc] initWithWindowNibName:@"GUProgressWindowController"];
}

- (NSString *)outputPathString
{
    return _outputFilePathControl.URL.path;
}

- (void)updateOutputPathControlWithNewFormat:(const std::string&)format
{
    if ([_inputFilePathControl.URL.path isEqualToString:@"/"])
        return;
    
    _outputFilePathControl.URL = [[_outputFilePathControl.URL URLByDeletingPathExtension]
                                  URLByAppendingPathExtension:[NSString stringWithUTF8String:format.c_str()]];
}

- (IBAction)_inputFilePathControlClicked:(NSPathControl *)sender
{
    NSOpenPanel *openPanel =[NSOpenPanel openPanel];
    [openPanel setCanChooseFiles:YES];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setAllowsMultipleSelection:YES];
    [openPanel setDirectoryURL:sender.clickedPathItem.URL];
    
    if ([p_fileFormatBox.outputFormatName isEqualToString:@"Use extension"]) {
        auto extensions = gene::Extensions::kFinderInputFileFormats();
        
        NSMutableArray *extensionsObj = [NSMutableArray new];
        for (const auto& ext : extensions)
            [extensionsObj addObject:[NSString stringWithUTF8String:ext.c_str()]];
        
        [openPanel setAllowedFileTypes:extensionsObj];
    }
    
    if ([openPanel runModal] == NSFileHandlingPanelOKButton) {
        _inputFilePathControl.URL = openPanel.URL;
        _outputFilePathControl.URL = [self _urlFromInputPathControl:openPanel.URL];
        _outputFilePathControl.enabled = YES;
        _splitButton.enabled = YES;
    }
}

- (IBAction)_outputFilePathControlClicked:(NSPathControl *)sender
{
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setDirectoryURL:sender.clickedPathItem.URL];
    
    NSString *fileName = [[GUUtils fileNameFromUrl:sender.URL]
                          stringByReplacingOccurrencesOfString:@"-splitN" withString:@""];
    NSString *pathExtension = [GUUtils fileNameFromUrl:sender.URL];
    
    if (fileName && [fileName isNotEqualTo:@"/"])
        savePanel.nameFieldStringValue = fileName;

    if ([savePanel runModal] == NSModalResponseOK) {
        _outputFilePathControl.URL = savePanel.URL;
        _outputFilePathControl.URL = [NSURL URLWithString:[[_outputFilePathControl.URL.path
                                                            stringByAppendingString:@"-splitN"]
                                                           stringByAppendingPathExtension:pathExtension]];
    }
}

- (IBAction)_splitButtonClicked:(id)sender
{
    if (_numberOfUnitsTextField.stringValue.length == 0) {
        [GUUtils showAlertWithMessage:[NSString stringWithFormat:@"%@%@%@", @"Number of ",
                                       _unitOfSeparationButton.title.lowercaseString,
                                       @" is not specified"] andImageNamed:@"NSCaution"];
        return;
    }
    
    if (_numberOfUnitsTextField.integerValue <= 0) {
        [GUUtils showAlertWithMessage:[NSString stringWithFormat:@"%@%@%@", @"Number of ",
                                       _unitOfSeparationButton.title.lowercaseString,
                                       @" should be greater than zero"] andImageNamed:@"NSCaution"];
        return;
    }
    
    NSString *outputFilePath = nil;
    
    if ([[_outputFilePathControl.URL URLByDeletingPathExtension].path hasSuffix:@"-splitN"]) {
        NSString *pathExtension = _outputFilePathControl.URL.pathExtension;
        outputFilePath = [[_outputFilePathControl.URL URLByDeletingPathExtension].path
                          stringByReplacingOccurrencesOfString:@"-splitN" withString:@""];
        outputFilePath = [outputFilePath stringByAppendingPathExtension:pathExtension];
    }
    
    auto flags = p_fileFormatBox.flags;
    flags->verbose = true;
    
    auto numberOfUnits = std::to_string(_numberOfUnitsTextField.intValue);
    if ([_unitOfSeparationButton.title isEqualToString:@"Files"])
        flags->SetSetting("f", numberOfUnits);
    else if ([_unitOfSeparationButton.title isEqualToString:@"Records"])
        flags->SetSetting("r", numberOfUnits);
    else if ([_unitOfSeparationButton.title isEqualToString:@"Kilobytes"])
        flags->SetSetting("sk", numberOfUnits);
    else /* Megabytes */
        flags->SetSetting("sm", numberOfUnits);
    std::string input_file_path = _inputFilePathControl.URL.path.UTF8String;
    std::string output_file_path = outputFilePath.UTF8String ?: "";
    __block auto splitter = std::make_unique<Splitter>(input_file_path,
                                                       output_file_path,
                                                       std::move(flags));
    if (!splitter) {
        return;
    }
    
    __weak id selfWeak = self;
    splitter->update_progress_callback = [selfWeak](float percentage)
    {
        return [selfWeak updateProgressTo:percentage];
    };
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [_progressWindow showProgessWindowWithMode:GUProgressWindowMode::Determinate];
        });
        
        __block BOOL code = splitter->Process();
        splitter = nullptr;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            bool wasCancelled = [_progressWindow dismissProgressViewController];
            [_progressWindow resetController];
            
            if (wasCancelled) {
                PrintfLog("CANCELLED");
                return;
            }
            
            if (code) {
                [GUUtils showAlertWithMessage:@"Split has completed successfully" andImageNamed:@"NSInfo"];
            } else {
                [GUUtils showAlertWithMessage:@"Input file was either empty, or it had an incorrect format" andImageNamed:@"NSError"];
            }
        });
        
    });
}

- (BOOL)updateProgressTo:(float)percent
{
    return [_progressWindow setProgress:percent];
}

- (void)operationDidCancel
{
    [_progressWindow dismissProgressViewController];
}

- (NSURL *)_urlFromInputPathControl:(NSURL *)inputUrl
{
    NSString *oldFileName = [GUUtils fileNameFromUrl:inputUrl];
    NSString *newFileName = [[oldFileName stringByAppendingString:@"-splitN"] stringByAppendingPathExtension:p_fileFormatBox.outputFormatExtension];
    return [[inputUrl URLByDeletingLastPathComponent] URLByAppendingPathComponent:newFileName];
}

@end

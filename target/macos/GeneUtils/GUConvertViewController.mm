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

#import "GUConvertViewController.h"
#import "GUFileFormatBoxController.h"
#import "GUUtils.h"
#import "GUProgressWindowController.h"

#include "Converter.hpp"
#include <libgene/flags/CommandLineFlags.hpp>
#include <libgene/utils/CppUtils.hpp>
#include <libgene/file/sequence/FastaFile.hpp>
#include <libgene/file/sequence/FastqFile.hpp>
#include <libgene/file/sequence/GenomicCsvFile.hpp>
#include <libgene/file/sequence/GenomicTsvFile.hpp>
#include <libgene/file/alignment/sam/SamFile.hpp>
#include <libgene/log/Logger.hpp>

@implementation GUConvertViewController
{
    IBOutlet NSPathControl *_inputPathControl;
    IBOutlet NSPathControl *_outputPathControl;
    IBOutlet NSButton *_convertButton;
    GUFileFormatBoxController *p_fileFormatBox;
    GUProgressWindowController *_progressWindow;
    IBOutlet NSButton *_openOutputFileButton;
    IBOutlet NSView *_fileFormatBoxView;
}

- (void)viewDidLoad
{
    p_fileFormatBox = [[GUFileFormatBoxController alloc] initWithNibName:@"GUFileFormatBox" bundle:nil];
    [_fileFormatBoxView addSubview:p_fileFormatBox.view];
    _progressWindow = [[GUProgressWindowController alloc] initWithWindowNibName:@"GUProgressWindowController"];
    p_fileFormatBox.delegate = self;
    p_fileFormatBox.dataSource = self;
    [p_fileFormatBox updateData];
    [super viewDidLoad];
}

- (NSString *)inputPathString
{
    return _inputPathControl.URL.path;
}

- (NSString *)outputPathString
{
    return _outputPathControl.URL.path;
}

- (void)updateOutputPathControlWithNewFormat:(const std::string&)format
{
    if ([_outputPathControl.URL.path isEqualToString:@"/"])
        return;
    
    _outputPathControl.URL = [[_outputPathControl.URL URLByDeletingPathExtension]
                              URLByAppendingPathExtension:[NSString
                                                           stringWithUTF8String:format.c_str()]];
}

- (NSURL *)_outputFileUrlFromInput:(NSURL *)inputFileUrl
{
    NSString *fileExtension = p_fileFormatBox.outputFormatExtension;
    NSString *fileName = [GUUtils fileNameFromUrl:inputFileUrl];
    
    return [[[inputFileUrl URLByDeletingLastPathComponent]
             URLByAppendingPathComponent:[fileName stringByAppendingString:@"-converted"]]
             URLByAppendingPathExtension:fileExtension];
}

- (IBAction)_selectInputFile:(NSPathControl *)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setDirectoryURL:sender.clickedPathItem.URL];
    
    NSMutableArray *supportedFileExtensions = [NSMutableArray new];
    auto fileExtensions = gene::SequenceFile::supportedExtensions();
    auto alignmentExtensions = gene::AlignmentFile::supportedExtensions();
    fileExtensions.insert(fileExtensions.end(),
                          alignmentExtensions.begin(), alignmentExtensions.end());
    
    for (const auto& ext : fileExtensions) {
        [supportedFileExtensions addObject:[NSString stringWithUTF8String:ext.c_str()]];
    }
    
    if ([p_fileFormatBox.inputFormatName isEqualToString:@"Use extension"])
        [openPanel setAllowedFileTypes:[supportedFileExtensions arrayByAddingObject:@"gz"]];
    
    if ([openPanel runModal] == NSModalResponseOK) {
        [_inputPathControl setURL:openPanel.URL];
        
        NSString *inputExtension = _inputPathControl.URL.pathExtension;
        if ([inputExtension isEqualToString:@"gz"])
            inputExtension = [[_inputPathControl.URL URLByDeletingPathExtension] pathExtension];
        
        
        inputExtension = [NSString stringWithUTF8String:gene::utils::extension2str(inputExtension.UTF8String).c_str()];
        
        if (inputExtension)
            [p_fileFormatBox updateOutputSelectorWithInputExtension:inputExtension];
        
        _convertButton.enabled = YES;
        _outputPathControl.enabled = YES;
        _outputPathControl.URL = [self _outputFileUrlFromInput:_inputPathControl.URL];
        _openOutputFileButton.enabled = [[NSFileManager defaultManager] fileExistsAtPath:_outputPathControl.URL.path];
    }
    [p_fileFormatBox updateData];
}

- (IBAction)_selectOutputFile:(NSPathControl *)sender
{
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setDirectoryURL:[sender.clickedPathItem.URL URLByDeletingPathExtension]];
    
    NSString *fileName = [[sender.URL URLByDeletingPathExtension] lastPathComponent];
    
    if (fileName && [fileName isNotEqualTo:@"/"])
        savePanel.nameFieldStringValue = fileName;
    
    if ([savePanel runModal] == NSModalResponseOK) {
        _outputPathControl.URL = [savePanel.URL URLByAppendingPathExtension:p_fileFormatBox.outputFormatExtension];
        _openOutputFileButton.enabled = [[NSFileManager defaultManager] fileExistsAtPath:_outputPathControl.URL.path];
    }
}

- (IBAction)_openOutputFile:(id)sender
{
    [[NSWorkspace sharedWorkspace] openFile:_outputPathControl.URL.path];
}

- (IBAction)_convertButtonClicked:(id)sender
{
    std::vector<std::string> inputPaths = {_inputPathControl.URL.path.UTF8String};
    
    BOOL isDirectory;
    [[NSFileManager defaultManager] fileExistsAtPath:_inputPathControl.URL.path
                                         isDirectory:&isDirectory];
    if (isDirectory) {
        NSString* pathToDirectory = _inputPathControl.URL.path;
        NSArray<NSString*> *folderContents = [[NSFileManager defaultManager]
                                              contentsOfDirectoryAtPath:pathToDirectory
                                                                  error:nil];
        for (NSString *filePath in folderContents) {
            std::string fullPath = [pathToDirectory stringByAppendingPathComponent:filePath].UTF8String;
            inputPaths.push_back(fullPath);
        }
    }
    
    __block auto converter = std::make_unique<Converter>(inputPaths,
                                                   ([_outputPathControl.URL isFileURL] ?
                                                    _outputPathControl.URL.path.UTF8String : ""),
                                                    p_fileFormatBox.flags);
    
    __weak id selfWeak = self;
    converter->update_progress_callback = [selfWeak](float percentage)
    {
        return [selfWeak updateProgressTo:percentage];
    };
    
    if (!converter)
        return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
    ^{
        dispatch_async(dispatch_get_main_queue(),
        ^{
            [_progressWindow showProgessWindowWithMode:GUProgressWindowMode::Determinate];
        });

        __block bool success = converter->Process();
        converter = nullptr;
        
        dispatch_async(dispatch_get_main_queue(),
        ^{
            bool wasCancelled = [_progressWindow dismissProgressViewController];
            [_progressWindow resetController];
            
            if (wasCancelled) {
                _openOutputFileButton.enabled = [[NSFileManager defaultManager] fileExistsAtPath:_outputPathControl.URL.path];
                PrintfLog("CANCELLED");
                return;
            }
            
            if (success) {
                [GUUtils showAlertWithMessage:@"Conversion has completed successfully" andImageNamed:@"NSInfo"];
                _openOutputFileButton.enabled = YES;
            } else
                [GUUtils showAlertWithMessage:@"Input file was either empty, or it had an incorrect format" andImageNamed:@"NSError"];
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

@end

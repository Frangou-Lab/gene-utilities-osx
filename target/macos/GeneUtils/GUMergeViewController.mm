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

#import "GUMergeViewController.h"
#import "GUFileFormatBoxController.h"
#import "GUProgressWindowController.h"
#import "GUUtils.h"

#include "Merger.hpp"
#include <libgene/utils/CppUtils.hpp>
#include <libgene/log/Logger.hpp>
#include <libgene/def/Extensions.hpp>

#include <string>
#include <vector>

@implementation GUMergeViewController
{
    IBOutlet NSTableView *_fileListTableView;
    IBOutlet NSPathControl *_mergedFilePathControl;
    NSMutableArray<NSString *> *_inputFilePaths;
    IBOutlet NSView *_fileFormatBoxView; 
    IBOutlet NSButtonCell *_removeSelectedButton;
    IBOutlet NSButton *_mergeButton;
    GUFileFormatBoxController *p_fileFormatBox;
    GUProgressWindowController *_progressWindow;
    IBOutlet NSButton *_openOutputFileButton;
}

- (void)viewDidLoad
{
    p_fileFormatBox = [[GUFileFormatBoxController alloc] initWithNibName:@"GUFileFormatBox" bundle:nil];
    [_fileFormatBoxView addSubview:p_fileFormatBox.view];
    _inputFilePaths = [NSMutableArray new];
    p_fileFormatBox.delegate = self;
    p_fileFormatBox.dataSource = self;
    p_fileFormatBox.inputOutputShouldntMatch = NO;
    [p_fileFormatBox updateData];
    _progressWindow = [[GUProgressWindowController alloc] initWithWindowNibName:@"GUProgressWindowController"];
    _fileListTableView.dataSource = self;
    _fileListTableView.delegate = self;
    [super viewDidLoad];
}

- (NSString *)outputPathString
{
    return _mergedFilePathControl.URL.path;
}

- (IBAction)_deleteSelectedRowsEntryInTableView:(id)sender
{
    NSIndexSet *selectedIndexSet = _fileListTableView.selectedRowIndexes;
    
    if ([_fileListTableView acceptsFirstResponder] && selectedIndexSet) {
        __block int deletedRows = 0;
        [selectedIndexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop)
        {
            [_inputFilePaths removeObjectAtIndex:idx - deletedRows];
            deletedRows++;
        }];
        [_fileListTableView deselectAll:nil];
        [_fileListTableView reloadData];
    }
}

- (IBAction)_addFilesButtonClicked:(NSButton *)sender
{
    NSOpenPanel *openPanel =[NSOpenPanel openPanel];
    [openPanel setCanChooseFiles:YES];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setAllowsMultipleSelection:YES];
    
    if ([p_fileFormatBox.inputFormatName isEqualToString:@"Use extension"]) {
        auto extensions = gene::Extensions::kFinderInputFileFormats();
        
        NSMutableArray *extensionsObj = [NSMutableArray new];
        for (const auto& ext : extensions)
            [extensionsObj addObject:[NSString stringWithUTF8String:ext.c_str()]];
        
        [openPanel setAllowedFileTypes:extensionsObj];
    }

    if ([openPanel runModal] == NSFileHandlingPanelOKButton) {
        for (NSURL *url in openPanel.URLs)
            [_inputFilePaths addObject:[url.path copy]];
    
        if ([_mergedFilePathControl.URL.path isEqualToString:@"/"] || !_mergedFilePathControl.enabled) {
            NSURL *mergedFileUrl = openPanel.URLs[0];
            NSString *fileName = [[mergedFileUrl URLByDeletingPathExtension] lastPathComponent];
            
            _mergedFilePathControl.URL = [[[openPanel.URLs[0] URLByDeletingLastPathComponent]
                                           URLByAppendingPathComponent:
                                           [fileName stringByAppendingString:@"-merged"]]
                                          URLByAppendingPathExtension:[NSString stringWithUTF8String:gene::utils::str2extension(p_fileFormatBox.outputFormatName.UTF8String).c_str()]];
            
            _openOutputFileButton.enabled = [[NSFileManager defaultManager] fileExistsAtPath:_mergedFilePathControl.URL.path];
        }
        [_fileListTableView reloadData];
    }
}

- (IBAction)_mergedFilePathControlClicked:(NSPathControl *)sender
{
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setDirectoryURL:sender.clickedPathItem.URL];
    
    NSString *fileName = [[sender.URL URLByDeletingPathExtension] lastPathComponent];
    
    if (fileName && [fileName isNotEqualTo:@"/"])
        savePanel.nameFieldStringValue = fileName;

    if ([savePanel runModal] == NSModalResponseOK) {
        sender.URL = [savePanel.URL URLByAppendingPathExtension:[NSString stringWithUTF8String:gene::utils::str2extension(p_fileFormatBox.outputFormatName.UTF8String).c_str()]];
        _openOutputFileButton.enabled = [[NSFileManager defaultManager] fileExistsAtPath:_mergedFilePathControl.URL.path];
    }
}

- (IBAction)_mergeButtonClicked:(id)sender
{
    std::vector<std::string> listOfPaths;
    for (NSString *path in _inputFilePaths) {
        listOfPaths.push_back(path.UTF8String);
    }
    
    __block auto merger = std::make_unique<Merger>(listOfPaths,
                                                   _mergedFilePathControl.URL.path.UTF8String,
                                                   p_fileFormatBox.flags);
    
    if (!merger)
    {
        return;
    }
    
    __weak id selfWeak = self;
    merger->update_progress_callback = [selfWeak](float percentage)
    {
        return [selfWeak updateProgressTo:percentage];
    };

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [_progressWindow showProgessWindowWithMode:GUProgressWindowMode::Determinate];
        });
        
        __block bool code = merger->Process();
        merger = nullptr;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            bool was_сancelled = [_progressWindow dismissProgressViewController];
            [_progressWindow resetController];
            
            if (was_сancelled) {
                _openOutputFileButton.enabled = [[NSFileManager defaultManager] fileExistsAtPath:_mergedFilePathControl.URL.path];
                PrintfLog("CANCELLED");
                return;
            }
            
            if (code) {
                _openOutputFileButton.enabled = YES;
                [GUUtils showAlertWithMessage:@"Merge has completed successfully" andImageNamed:@"NSInfo"];
            } else
                [GUUtils showAlertWithMessage:@"Input file was either empty, or it had an incorrect format" andImageNamed:@"NSError"];
        });
        
    });
}

- (IBAction)_openOutputFile:(id)sender
{
    [[NSWorkspace sharedWorkspace] openFile:_mergedFilePathControl.URL.path];
}

- (void)updateOutputPathControlWithNewFormat:(const std::string&)format
{
    if ([_mergedFilePathControl.URL.path isEqualToString:@"/"])
        return;
    
    _mergedFilePathControl.URL = [[_mergedFilePathControl.URL URLByDeletingPathExtension]
                                  URLByAppendingPathExtension:[NSString stringWithUTF8String:format.c_str()]];
}

- (BOOL)updateProgressTo:(float)percent
{
    return [_progressWindow setProgress:percent];
}

- (void)operationDidCancel
{
    [_progressWindow dismissProgressViewController];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableVie
{
    BOOL fileListIsNotEmpty = _inputFilePaths.count != 0;
    
    _removeSelectedButton.enabled = fileListIsNotEmpty;
    _mergeButton.enabled = fileListIsNotEmpty;
    _mergedFilePathControl.enabled = fileListIsNotEmpty;

    return _inputFilePaths.count;
}

- (nullable id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    return _inputFilePaths[rowIndex];
}

@end

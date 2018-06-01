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

#include <fstream>
#include <string>
#include <deque>
#include <stdexcept>

#import "GUExtractViewController.h"
#import "GUProgressWindowController.h"
#import "GUUtils.h"

#include "Extractor.hpp"
#include <libgene/flags/CommandLineFlags.hpp>
#include <libgene/def/Flags.hpp>
#include <libgene/io/streams/PlainStringInputStream.hpp>
#include <libgene/log/Logger.hpp>
#include <libgene/utils/CppUtils.hpp>
#include <libgene/utils/FileUtils.hpp>
#include <libgene/utils/StringUtils.hpp>
#include <libgene/def/Extensions.hpp>
#include <libgene/search/FuzzySearch.hpp>

@implementation GUExtractViewController
{
    std::vector<std::string> query_strings_;
    IBOutlet NSPathControl *referenceFilePathControl;
    IBOutlet NSPathControl *outputFilePathControl;
    IBOutlet NSPopUpButton *inputFormatSelector;
    IBOutlet NSTableView *queryTableView;
    IBOutlet NSButton *extractButton;
    IBOutlet NSButton *removeSelectedButton;
    IBOutlet NSTextField *newQueryTextField;
    
    IBOutlet NSButton *searchInSequencesRadioButton;
    IBOutlet NSButton *searchInIDsRadioButton;
    IBOutlet NSButton *searchBasedOnBarcodesRadioButton;
    
    IBOutlet NSButton *barcodeIsInSequenceCheckbox;
    GUProgressWindowController *progressWindow;
    IBOutlet NSButton *openOutputFileButton;
    
    IBOutlet NSTextField *cutoffSequenceLengthTextField;
    IBOutlet NSButton *cutoffLengthLabel;
    IBOutlet NSButton *barcodeIsInR2Checkbox;
    IBOutlet NSButton *ntLabel;
    IBOutlet NSButton *enableErrorCorrection;
    
    IBOutlet NSButton *enqueCurrentJob;
    IBOutlet NSButton *dequeLastJob;
    std::deque<ExtractorJob> job_queue_;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    progressWindow = [[GUProgressWindowController alloc] initWithWindowNibName:@"GUProgressWindowController"];
    [queryTableView setTarget:self];
    queryTableView.delegate = self;
    queryTableView.dataSource = self;
}

- (NSURL *)outputFileUrlFromInput:(NSURL *)inputFileUrl
                      isDirectory:(BOOL)isDirectory
                    pathExtension:(std::string)extension
{
    std::string file_name = inputFileUrl.lastPathComponent.UTF8String;
    if (!isDirectory) {
        // Remove extension
        auto dot_position = file_name.rfind('.');
        if (dot_position != std::string::npos)
            file_name.erase(dot_position);
    }
    return [[inputFileUrl URLByDeletingLastPathComponent] URLByAppendingPathComponent:[NSString stringWithUTF8String:(file_name + "-extracted." + extension).c_str()]];
}

- (IBAction)refenceFilePathControlClicked:(NSPathControl *)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setDirectoryURL:sender.clickedPathItem.URL];
    
    if ([inputFormatSelector.title isEqualToString:@"Use extension"]) {
        auto extensions = gene::Extensions::kFinderInputFileFormats();
        
        NSMutableArray *extensionsObj = [NSMutableArray new];
        for (const auto& ext : extensions)
            [extensionsObj addObject:[NSString stringWithUTF8String:ext.c_str()]];
        
        [openPanel setAllowedFileTypes:extensionsObj];
    }
    
    if ([openPanel runModal] == NSModalResponseOK) {
        [referenceFilePathControl setURL:openPanel.URL];
        outputFilePathControl.enabled = YES;
        
        BOOL isDirectory;
        std::string output_extension = [self GetOutputFileExtension:&isDirectory];
        outputFilePathControl.URL = [self outputFileUrlFromInput:referenceFilePathControl.URL
                                                     isDirectory:isDirectory
                                                   pathExtension:output_extension];
        
        openOutputFileButton.enabled = [[NSFileManager defaultManager] fileExistsAtPath:outputFilePathControl.URL.path] &&
                                         (searchBasedOnBarcodesRadioButton.state == NSControlStateValueOff);
        extractButton.enabled = !query_strings_.empty();
        enqueCurrentJob.enabled = extractButton.enabled;
    }
}

- (IBAction)barcodeInSequenceToggled:(id)sender
{
    cutoffSequenceLengthTextField.enabled = (barcodeIsInSequenceCheckbox.state == NSControlStateValueOn);
    cutoffLengthLabel.enabled = (barcodeIsInSequenceCheckbox.state == NSControlStateValueOn);
    ntLabel.enabled = cutoffLengthLabel.enabled;
    
    // 'Barcode in R2' and 'Barcode in sequence' are mutually exclusive
    barcodeIsInR2Checkbox.enabled = (barcodeIsInSequenceCheckbox.state == NSControlStateValueOff);
}

- (IBAction)barcodeInR2Toggled:(id)sender
{
    cutoffSequenceLengthTextField.enabled = (barcodeIsInSequenceCheckbox.state == NSControlStateValueOn);
    cutoffLengthLabel.enabled = (barcodeIsInSequenceCheckbox.state == NSControlStateValueOn);
    ntLabel.enabled = cutoffLengthLabel.enabled;
    
    // 'Barcode in R2' and 'Barcode in sequence' are mutually exclusive
    barcodeIsInSequenceCheckbox.enabled = (barcodeIsInR2Checkbox.state == NSControlStateValueOff);
}

- (std::string)GetOutputFileExtension:(nullable BOOL *)isDirectory
{
    std::string input_extension;
    
    if (isDirectory != nil)
        *isDirectory = NO;
    
    if ([inputFormatSelector.title isEqualToString:@"Use extension"]) {
        [[NSFileManager defaultManager] fileExistsAtPath:referenceFilePathControl.URL.path
                                             isDirectory:isDirectory];
        
        if (isDirectory != nil && *isDirectory)
            input_extension = [self GetExtensionForFolderContents:referenceFilePathControl.URL];
        else
            input_extension = referenceFilePathControl.URL.pathExtension.UTF8String;
    } else {
        input_extension = gene::utils::str2extension(inputFormatSelector.title.UTF8String);
    }
    
    if (input_extension == "gz")
        input_extension = [[referenceFilePathControl.URL URLByDeletingPathExtension] pathExtension].UTF8String;
    
    return input_extension;
}

- (IBAction)inputFormatSelectorClicked:(id)sender
{
    if (referenceFilePathControl.URL.path.length == 0 ||
        [outputFilePathControl.URL.path isEqualToString:@"/"])
        return;
    
    BOOL isDirectory;
    outputFilePathControl.URL = [[outputFilePathControl.URL URLByDeletingPathExtension]
                                  URLByAppendingPathExtension:[NSString stringWithUTF8String:[self GetOutputFileExtension:&isDirectory].c_str()]];
    
    openOutputFileButton.enabled = [[NSFileManager defaultManager] fileExistsAtPath:outputFilePathControl.URL.path] &&
                                     (searchBasedOnBarcodesRadioButton.state == NSControlStateValueOff);
}

- (IBAction)outputFilePathControlClicked:(NSPathControl *)sender
{
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setDirectoryURL:sender.clickedPathItem.URL];
    
    NSString *fileName = [[sender.URL URLByDeletingPathExtension] lastPathComponent];
    
    if (fileName && [fileName isNotEqualTo:@"/"])
        savePanel.nameFieldStringValue = fileName;

    if ([savePanel runModal] == NSModalResponseOK) {
        BOOL isDirectory;
        std::string pathExtension = [self GetOutputFileExtension:&isDirectory];
        outputFilePathControl.URL = [savePanel.URL URLByAppendingPathExtension:[NSString stringWithUTF8String:pathExtension.c_str()]];
        openOutputFileButton.enabled = [[NSFileManager defaultManager] fileExistsAtPath:outputFilePathControl.URL.path] &&
                                        (searchBasedOnBarcodesRadioButton.state == NSControlStateValueOff);
    }
}

- (IBAction)openOutputFile:(id)sender
{
    if (searchBasedOnBarcodesRadioButton.state == NSControlStateValueOff)
        [[NSWorkspace sharedWorkspace] openFile:outputFilePathControl.URL.path];
}

- (IBAction)addItemClicked:(id)sender
{
    if (newQueryTextField.stringValue.length > 0) {
        query_strings_.push_back(newQueryTextField.stringValue.UTF8String);
        newQueryTextField.stringValue = @"";
    }
    extractButton.enabled = !query_strings_.empty() &&
                             ![referenceFilePathControl.URL.path isEqualToString:@"/"];
    enqueCurrentJob.enabled = extractButton.enabled;
    [queryTableView reloadData];
}

- (IBAction)loadItemsFromFile:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel new];
    [openPanel setDirectoryURL:referenceFilePathControl.URL];
    [openPanel setAllowedFileTypes:@[@"txt"]];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setCanChooseDirectories:NO];
    
    if ([openPanel runModal] == NSModalResponseOK) {
        query_strings_.clear();
        gene::PlainStringInputStream queries_file(openPanel.URL.path.UTF8String);
        if (queries_file) {
            std::string line;
            while (!(line = queries_file.ReadLine()).empty()) {
                query_strings_.push_back(line);
            }
        }
        [queryTableView reloadData];
    }
}

- (IBAction)removeSelectedButtonClicked:(id)sender
{
    NSIndexSet *selectedIndexSet = queryTableView.selectedRowIndexes;
    if ([queryTableView acceptsFirstResponder] && selectedIndexSet) {
        __block int deletedRows = 0;
        [selectedIndexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
            query_strings_.erase((query_strings_.begin() + idx) - deletedRows);
            deletedRows++;
        }];
        [queryTableView deselectAll:nil];
        [queryTableView reloadData];
    }
}

- (IBAction)searchTargetChanges:(NSButton *)sender
{
    barcodeIsInSequenceCheckbox.enabled = searchBasedOnBarcodesRadioButton.state == NSControlStateValueOn;
    BOOL demultiplex = (searchBasedOnBarcodesRadioButton.state == NSControlStateValueOn);
    cutoffLengthLabel.enabled = demultiplex && (barcodeIsInSequenceCheckbox.state == NSControlStateValueOn);
    ntLabel.enabled = cutoffLengthLabel.enabled;
    cutoffSequenceLengthTextField.enabled = cutoffLengthLabel.enabled;
    barcodeIsInR2Checkbox.enabled = searchBasedOnBarcodesRadioButton.state == NSControlStateValueOn;
    enableErrorCorrection.enabled = barcodeIsInSequenceCheckbox.enabled;
}

- (IBAction)extractButtonClicked:(id)sender
{
    if (job_queue_.empty())
        [self enqueCurrentJob];
    
    [newQueryTextField.window makeFirstResponder:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        [progressWindow showProgessWindowWithMode:GUProgressWindowMode::DeterminateMultipleJobs];
        progressWindow.numberOfFiles = job_queue_.size() + 1;
    });
    [self performExtract];
}

- (void)performExtract
{
    if (job_queue_.empty()) {
        // This can happen if the job was found to be malformed at the
        // late stage
        dispatch_async(dispatch_get_main_queue(), ^{
            [progressWindow dismissProgressViewController];
            [progressWindow resetController];
        });
        return;
    }
    
    auto job = std::move(job_queue_.front());
    __block auto extractor = std::make_unique<Extractor>(std::move(job));
    job_queue_.pop_front();
    
    if (!extractor)
        return;

    [newQueryTextField.window makeFirstResponder:nil];
    
    __weak id selfWeak = self;
    extractor->update_progress_callback = [selfWeak](float percentage) {
        return [selfWeak updateProgressTo:percentage];
    };
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block bool code;
        try {
             code = extractor->Process();
        } catch (...) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [progressWindow cancelCurrentTask];
                [progressWindow dismissProgressViewController];
                NSString* text = @"Found a pair of reads that don't correspond to each other.\n\nSee the Log for more details.";
                [GUUtils showAlertWithMessage:text andImageNamed:@"NSError"];
            });
            return;
        }
        extractor = nullptr;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            bool was_сancelled = [progressWindow cancelWasClicked];
            
            if (job_queue_.empty() || was_сancelled) {
                [progressWindow dismissProgressViewController];
                if (was_сancelled) {
                    openOutputFileButton.enabled = [[NSFileManager defaultManager]
                                                     fileExistsAtPath:outputFilePathControl.URL.path] &&
                    (searchBasedOnBarcodesRadioButton.state == NSControlStateValueOff);
                    PrintfLog("CANCELLED");
                    [progressWindow resetController];
                    return;
                }
            } else if (!job_queue_.empty()) {
                [progressWindow setNumberOfCurrentFile:progressWindow.numberOfFiles -
                                                        job_queue_.size() + 1];
                // Recursively dispatch the next job in queue
                [selfWeak performExtract];
                // It will show the completion dialogue on the last iteration
                return;
            }
            
            if (code) {
                openOutputFileButton.enabled = (searchBasedOnBarcodesRadioButton.state == NSControlStateValueOff);
                [GUUtils showAlertWithMessage:@"Extract has completed successfully"
                                andImageNamed:@"NSInfo"];
            } else {
                NSString* text = @"Input file was either empty, or it had an incorrect format";
                [GUUtils showAlertWithMessage:text andImageNamed:@"NSError"];
            }
            extractButton.title = @"Extract";
            [self updateDequeLastJobButtonState];
        });
    });
}

- (void)updateDequeLastJobButtonState
{
    dequeLastJob.enabled = !job_queue_.empty();
}

- (IBAction)endEditingText:(NSTextField *)sender
{
    [self addItemClicked:nil];
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    query_strings_[row] = ((NSString *)object).UTF8String;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableVie
{
    BOOL fileListEmpty = query_strings_.empty();
    extractButton.enabled = !fileListEmpty && ![referenceFilePathControl.URL.path isEqualToString:@"/"];
    enqueCurrentJob.enabled = extractButton.enabled;
    
    if (fileListEmpty)
        removeSelectedButton.enabled = fileListEmpty;
    
    return query_strings_.size();
}

- (nullable id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    return [NSString stringWithUTF8String:query_strings_[rowIndex].c_str()];
}

- (BOOL)updateProgressTo:(float)percent
{
    return [progressWindow setProgress:percent];
}

- (NSURL *)outputFileUrlFromInput
{
    BOOL is_directory;
    [[NSFileManager defaultManager] fileExistsAtPath:referenceFilePathControl.URL.path isDirectory:&is_directory];
    
    std::string input_extension;
    NSURL *input_file_url;
    if ([inputFormatSelector.title isEqualToString:@"Use extension"]) {
        if (is_directory) {
            input_extension = [self GetExtensionForFolderContents:referenceFilePathControl.URL];
            std::string folder_name = gene::utils::GetLastPathComponent(referenceFilePathControl.URL.path.UTF8String);
            folder_name = folder_name + '.' + input_extension;
            input_file_url = [[referenceFilePathControl.URL URLByDeletingLastPathComponent] URLByAppendingPathComponent:[NSString stringWithUTF8String:folder_name.c_str()]];
        } else {
            input_file_url = referenceFilePathControl.URL;
        }
    } else {
        input_extension = gene::utils::str2extension(inputFormatSelector.title.UTF8String);
    }

    std::string out_file_name = gene::utils::GetLastPathComponent(input_file_url.path.UTF8String);
    auto dot_position = out_file_name.rfind('.');
    if (dot_position != std::string::npos)
        out_file_name.erase(dot_position);
    
    out_file_name += "-extracted";
    out_file_name += '.' + input_extension;
    return [[input_file_url URLByDeletingLastPathComponent] URLByAppendingPathComponent:[NSString stringWithUTF8String:out_file_name.c_str()]];
}

- (std::string)GetExtensionForFolderContents:(NSURL *)folderUrl
{
    NSArray<NSString *> *fileNames = [[NSFileManager defaultManager]
                                      contentsOfDirectoryAtPath:folderUrl.path error:nil];
    std::string file_extension;
    for (NSString *fileName in fileNames) {
        std::string file_name = fileName.UTF8String;
        if (gene::utils::str2type(gene::utils::GetExtension(file_name)) != gene::FileType::Unknown) {
            file_extension = gene::utils::extension2str(gene::utils::GetExtension(fileName.UTF8String));
            break;
        }
    }
    return file_extension;
}

- (IBAction)enqueCurrentJobButtonClicked:(id)sender
{
    [self enqueCurrentJob];
    [self updateExtractButtonCount];
    [self updateDequeLastJobButtonState];
}

- (void)enqueCurrentJob
{
    auto flags = std::make_unique<gene::CommandLineFlags>();
    flags->verbose = true;
    
    if (searchInSequencesRadioButton.state == NSControlStateValueOn) {
        flags->SetSetting(gene::Flags::kTagIsInSequence);
    }
    if (searchBasedOnBarcodesRadioButton.state == NSControlStateValueOn) {
        flags->SetSetting(gene::Flags::kDemultiplexByTags);
    }
    if (![inputFormatSelector.title isEqualToString:@"Use extension"]) {
        std::string inputFormat = inputFormatSelector.title.UTF8String;
        flags->SetSetting(gene::Flags::kInputFormat, inputFormat);
    }
    if (barcodeIsInSequenceCheckbox.state == NSControlStateValueOn &&
        barcodeIsInSequenceCheckbox.enabled) {
        flags->SetSetting(gene::Flags::kSolexaFastqCutoffLength,
                          std::to_string(cutoffSequenceLengthTextField.intValue));
    }
    if (barcodeIsInR2Checkbox.state == NSControlStateValueOn && barcodeIsInR2Checkbox.enabled) {
        flags->SetSetting(gene::Flags::kIlluminaR2Tags);
    }
    if (enableErrorCorrection.state == NSControlStateValueOn && enableErrorCorrection.enabled) {
        flags->SetSetting(gene::Flags::kDemultiplexWithErrorCorrection);
    }
    
    NSString* outputFilePath = outputFilePathControl.URL.path;
    NSString *fileName = [[outputFilePath lastPathComponent] stringByDeletingPathExtension];
    NSString *pathExtension = outputFilePath.pathExtension;
    
    int trimLength = flags->GetIntSetting(gene::Flags::kSolexaFastqCutoffLength);
    bool solexaVariant = flags->SettingExists(gene::Flags::kSolexaFastqCutoffLength);
    auto NameForQuery = [=](const std::string& query) -> std::string
    {
        NSString *pathToFile = [outputFilePath stringByDeletingLastPathComponent];
        if (solexaVariant) {
            return [pathToFile stringByAppendingPathComponent:[fileName
                                                               stringByAppendingFormat:@"_%s_N%i.%@", query.c_str(),
                                                               trimLength, pathExtension]].UTF8String;
        } else {
            return [pathToFile stringByAppendingPathComponent:[fileName
                                                               stringByAppendingFormat:@"_%s.%@", query.c_str(),
                                                               pathExtension]].UTF8String;
        }
    };

    std::vector<std::pair<std::string, std::string>> input_paths;
    std::vector<std::pair<std::string, std::string>> output_paths;

    std::string path_control_value = referenceFilePathControl.URL.path.UTF8String;
    input_paths.push_back({path_control_value, ""});
    if (gene::utils::IsDirectory(path_control_value)) {
        auto directory_contents = gene::utils::GetDirectoryContents(path_control_value);
        for (const auto& file_path : directory_contents) {
            input_paths.push_back({file_path, ""});
        }
    }

    if (flags->SettingExists(gene::Flags::kIlluminaR2Tags)) {
        // This option requires all files to be in pairs:
        // ..._R1 and its corresponding barcode file ..._R2
        //
        // The loop starts at 1 because the first string is the directory path.
        for (int i = 1; i < input_paths.size(); i += 2) {
            // Has to be "_R1_"
            auto r1_name = gene::utils::GetLastPathComponent(input_paths[i].first);
            // Has to be "_R2_"
            auto r2_name = gene::utils::GetLastPathComponent(input_paths[i + 1].first);
            auto r2_position = r2_name.find("_R2_");

            bool bad_input = false;
            if (r2_position == std::string::npos) {
                bad_input = true;
            } else {
                // Test that after changing _R2_ into _R1_ file names match.
                r2_name.replace(r2_position, 4, "_R1_");
                bad_input = (r2_name != r1_name);
            }
            if (bad_input) {
                std::string warning_message = "File named \"" + r1_name + "\" doesn't have a corresponding _R2_ file";
                [GUUtils showAlertWithMessage:[NSString stringWithUTF8String:warning_message.c_str()]
                                andImageNamed:@"NSWarn"];
                PrintfLog("[ERROR] Extract aborted due to malformed input");
                return;
            }
        }
    }
    
    if (flags->SettingExists(gene::Flags::kDemultiplexByTags)) {
        for (const auto& barcode: query_strings_) {
            output_paths.push_back({std::string(NameForQuery(barcode)), std::string()});
        }
    } else {
        output_paths.push_back({std::string(outputFilePathControl.URL.path.UTF8String), std::string()});
    }

    ExtractorJob job(input_paths, output_paths,
                     std::move(flags), query_strings_);
    job_queue_.emplace_back(std::move(job));
}

- (IBAction)dequeLastJob:(id)sender
{
    if (job_queue_.empty())
        return;
    
    job_queue_.pop_back();
    [self updateExtractButtonCount];
    [self updateDequeLastJobButtonState];
}

- (void)updateExtractButtonCount
{
    if (!job_queue_.empty())
        extractButton.title = [NSString stringWithFormat:@"Extract (%ld)", job_queue_.size()];
    else
        extractButton.title = @"Extract";
}

@end

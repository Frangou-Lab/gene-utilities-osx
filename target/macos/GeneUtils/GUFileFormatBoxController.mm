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

#import "GUFileFormatBoxController.h"

#include <libgene/file/sequence/SequenceFile.hpp>
#include <libgene/file/alignment/AlignmentFile.hpp>
#include <libgene/flags/CommandLineFlags.hpp>
#include <libgene/utils/CppUtils.hpp>
#include <libgene/def/Flags.hpp>

#include <algorithm>
#include <string>
#include <map>

@implementation GUFileFormatBoxController
{
    std::map<std::string, NSMenuItem *> _menuItemForFormat;
    std::map<std::string, std::pair<char, char>> _qualityLimitsForFastq;
    IBOutlet NSPopUpButton *_inputFormatSelector;
    IBOutlet NSPopUpButton *_outputFormatSelector;
    IBOutlet NSMenu *_outputFormatMenu;
    
    // Fasta
    IBOutlet NSButton *_splitFastaCheckbox;
    // Fastq
    IBOutlet NSButton *_duplicateFastqIdsCheckbox;
    IBOutlet NSButton *_defaultQualityCheckbox;
    IBOutlet NSTextField *_qualityTextfield;
    //Csv/tsv
    IBOutlet NSButton *_omitQualityCheckbox;
    IBOutlet NSButton *_ignoreColumnDefsCheckbox;
    IBOutlet NSButton *_reorderOutputColumnsCheckbox;
    IBOutlet NSTextField *_columnsOutputOrderTextField;
    IBOutlet NSButton *_reorderInputColumnsCheckbox;
    IBOutlet NSTextField *_columnsInputOrderTextField;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
        return nil;
    
    auto sequenceFileFormats = gene::SequenceFile::defaultFileFormats();
    
    // A bit of a hack. Add more specific FASTQ formats manually
    auto fastqPosition = std::find(sequenceFileFormats.begin(), sequenceFileFormats.end(),
                                   std::string("fastq"));
    if (fastqPosition != sequenceFileFormats.end()) {
        std::vector<std::string> fastqFormats = {"fastq - Illumina 1.8+",
                                                 "fastq - Illumina 1.5",
                                                 "fastq - Illumina 1.3",
                                                 "fastq - Sanger",
                                                 "fastq - Solexa"};

        // Open Wikipedia - 'FASTQ Format' for reference. Then it should make sense.
        _qualityLimitsForFastq[fastqFormats[0] /* 1.8+ */] = std::make_pair('!', 'J');
        _qualityLimitsForFastq[fastqFormats[1] /* 1.5 */] = std::make_pair('B', 'h');
        _qualityLimitsForFastq[fastqFormats[2] /* 1.3 */] = std::make_pair('@', 'h');
        _qualityLimitsForFastq[fastqFormats[3] /* Sanger */] = std::make_pair('!', 'I');
        _qualityLimitsForFastq[fastqFormats[4] /* Solexa */] = std::make_pair(';', 'h');
        
        sequenceFileFormats.insert(fastqPosition, fastqFormats.begin(), fastqFormats.end());
        fastqPosition = std::find(sequenceFileFormats.begin(), sequenceFileFormats.end(),
                                  std::string("fastq"));
        sequenceFileFormats.erase(fastqPosition);
    }
    
    for (const auto& format : sequenceFileFormats) {
        auto displayName = format;
        if (format.find("csv") != std::string::npos || format.find("tsv") != std::string::npos)
            displayName = gene::utils::extension2str(format);

        NSString *displayFormat = [NSString stringWithUTF8String:displayName.c_str()];
        _menuItemForFormat[format] = [[NSMenuItem alloc] initWithTitle:displayFormat
                                                                action:nil
                                                         keyEquivalent:@""];
    }
    for (const auto& format : gene::AlignmentFile::defaultFileFormats()) {
        auto str = gene::utils::extension2str(format);
        NSString *displayFormat = [NSString stringWithUTF8String:str.c_str()];
        _menuItemForFormat[format] = [[NSMenuItem alloc] initWithTitle:displayFormat
                                                                action:nil
                                                         keyEquivalent:@""];
    }
    _inputOutputShouldntMatch = YES;
    return self;
}

- (IBAction)_outputFormatSelectorClicked:(NSPopUpButton *)sender
{
    if ([_delegate respondsToSelector:@selector(updateOutputPathControlWithNewFormat:)]) {
        auto extension = gene::utils::str2extension(_outputFormatSelector.title.UTF8String);
        [_delegate updateOutputPathControlWithNewFormat:extension];
    }
    [self _updateEnabledCheckBoxes];
}

- (IBAction)_inputFormatSelectorClicked:(NSPopUpButton *)sender
{
    if (!_inputOutputShouldntMatch) {
        [self _updateEnabledCheckBoxes];
        return;
    }
    
    std::string inputFileExtension = sender.title.UTF8String;
    [_outputFormatSelector removeAllItems];
    BOOL newMenu = NO;
    BOOL inputPathEmpty = [[_dataSource inputPathString] isEqualToString:@"/"];
    if (inputFileExtension == "Use extension") {
        if (inputPathEmpty) {
            newMenu = YES;
        } else {
            std::string extension = [self _pathExtensionFromInputPathControl].UTF8String;
            inputFileExtension = gene::utils::extension2str(extension);
            _ignoreColumnDefsCheckbox.hidden = inputFileExtension == "csv" ||
                                               inputFileExtension == "tsv";
        }
    }
    
    for (const auto& entry : _menuItemForFormat) {
        NSMenuItem *item = entry.second;
        item.state = 0;
        bool isAlignmentFormat = [item.title isEqualToString:@"sam"] ||
                                 [item.title isEqualToString:@"bam"];
        
        if ((newMenu || (item.title.UTF8String != inputFileExtension)) && !isAlignmentFormat)
            [_outputFormatSelector.menu addItem:item];
    }
    
    if ([_delegate respondsToSelector:@selector(updateOutputPathControlWithNewFormat:)]) {
        auto extension = gene::utils::str2extension(_outputFormatSelector.title.UTF8String);
        [_delegate updateOutputPathControlWithNewFormat:extension];
    }
    //
    [self _updateEnabledCheckBoxes];
}

- (IBAction)_setDefaultQualityChecked:(NSButton *)sender
{
    BOOL checkboxOn = (sender.state == NSControlStateValueOn);
    if (checkboxOn)
        _qualityTextfield.hidden = NO;
    
    _qualityTextfield.enabled = checkboxOn;
}

- (IBAction)_defaultQualityTextEntered:(NSTextField *)sender
{
    char qualityMin = '!';
    char qualityMax = 'I';

    if ([_outputFormatSelector.title hasPrefix:@"fastq"]) {
        qualityMin = _qualityLimitsForFastq[_outputFormatSelector.title.UTF8String].first;
        qualityMax = _qualityLimitsForFastq[_outputFormatSelector.title.UTF8String].second;
    }

    if (sender.stringValue.length == 0) {
        if ([_outputFormatSelector.title hasPrefix:@"fastq"])
            sender.stringValue = [NSString stringWithFormat:@"%c", qualityMax];
    } else {
        if (sender.stringValue.UTF8String[0] < qualityMin)
            sender.stringValue = [NSString stringWithFormat:@"%c", qualityMin];
        else if (sender.stringValue.UTF8String[0] > qualityMax)
            sender.stringValue = [NSString stringWithFormat:@"%c", qualityMax];
        else
            sender.stringValue = [sender.stringValue stringByPaddingToLength:1
                                                                  withString:@""
                                                             startingAtIndex:1];
    }
}

- (IBAction)_reorderOutputColumnsCheckboxChecked:(NSButton *)sender
{
    BOOL checkboxOn = (sender.state == NSControlStateValueOn);
    if (checkboxOn)
        _columnsOutputOrderTextField.hidden = NO;
    
    _columnsOutputOrderTextField.enabled = checkboxOn;
}

- (IBAction)_reorderInputColumnsCheckboxChecked:(NSButton *)sender
{
    BOOL checkboxOn = (sender.state == NSControlStateValueOn);
    if (checkboxOn)
        _columnsInputOrderTextField.hidden = NO;
    
    _columnsInputOrderTextField.enabled = checkboxOn;
}

- (NSString *)inputFormatExtension
{
    auto extension = gene::utils::str2extension(_inputFormatSelector.title.UTF8String);
    return [NSString stringWithUTF8String:extension.c_str()];
}

- (NSString *)inputFormatName
{
    return _inputFormatSelector.title;
}

- (NSString *)outputFormatExtension
{
    auto extension = gene::utils::str2extension(_outputFormatSelector.title.UTF8String);
    return [NSString stringWithUTF8String:extension.c_str()];
}

- (NSString *)outputFormatName
{
    return _outputFormatSelector.title;
}

- (std::unique_ptr<gene::CommandLineFlags>)flags
{
    auto flags = std::make_unique<gene::CommandLineFlags>();
    
    std::string inputFormatSelected = _inputFormatSelector.title.UTF8String;
    if (inputFormatSelected != "Use extension")
    {
        if (inputFormatSelected.find('-') == std::string::npos)
        {
            // No suffix provided.
            flags->SetSetting(gene::Flags::kInputFormat, inputFormatSelected);
        }
        else
        {
            auto variant = gene::utils::FormatNameToVariant(inputFormatSelected);
            flags->SetSetting(gene::Flags::kInputFormat, "fastq-" + gene::utils::FastqVariantToSuffix(variant));
        }
    }
    
    std::string outputFormatSelected = _outputFormatSelector.title.UTF8String;
    if (outputFormatSelected.find('-') == std::string::npos) {
        // No suffix provided.
        flags->SetSetting(gene::Flags::kOutputFormat, outputFormatSelected);
    } else {
        auto variant = gene::utils::FormatNameToVariant(outputFormatSelected);
        flags->SetSetting(gene::Flags::kOutputFormat, "fastq-" + gene::utils::FastqVariantToSuffix(variant));
    }
    
    flags->verbose = true;

    // Additional flags
    if (!_omitQualityCheckbox.hidden /* csv/tsv output */) {
        if (_omitQualityCheckbox.state == NSControlStateValueOn)
            flags->SetSetting(gene::Flags::kOmitQuality, "");
            
        if (_ignoreColumnDefsCheckbox.state == NSControlStateValueOn)
            flags->SetSetting("nocolumndefs", " ");

        if (_reorderInputColumnsCheckbox.state == NSControlStateValueOn)
            flags->SetSetting(gene::Flags::kReorderInputColumns,
                              _columnsInputOrderTextField.stringValue.UTF8String);

        if (_reorderOutputColumnsCheckbox.state == NSControlStateValueOn)
            flags->SetSetting(gene::Flags::kReorderOutputColumns,
                              _columnsOutputOrderTextField.stringValue.UTF8String);
    } else if (!_splitFastaCheckbox.hidden /* fasta output */) {
        if (_splitFastaCheckbox.state == NSControlStateValueOn)
            flags->SetSetting("splitfasta", " ");
    } else /* fastq output */ {
        if (_defaultQualityCheckbox.state == NSControlStateValueOn)
            flags->SetSetting(gene::Flags::kOverrideExistingQuality, "");

        if (_duplicateFastqIdsCheckbox.state == NSControlStateValueOn)
            flags->SetSetting("duplicatefastqids", " ");
    }
    flags->SetSetting(gene::Flags::kFastqQuality, _qualityTextfield.stringValue.UTF8String);
    return flags;
}

- (void)updateData
{
    [self _updateEnabledCheckBoxes];
}

- (void)updateOutputSelectorWithInputExtension:(NSString *)inputFileExtension
{
    [_outputFormatSelector removeAllItems];
    for (const auto& entry : _menuItemForFormat) {
        NSMenuItem* item = entry.second;

        item.state = 0;
        if ([item.title isNotEqualTo:inputFileExtension] &&
            [item.title isNotEqualTo:@"bam"] &&
            [item.title isNotEqualTo:@"sam"] &&
            [item.title isNotEqualTo:@"gb"])
        {
            [_outputFormatSelector.menu addItem:item];
        }
    }
    [self _updateFastqOutputQuality];
}

- (void)_updateFastqOutputQuality
{
    char qualityMin = '!';
    char qualityMax = 'I';
    
    if ([_outputFormatSelector.title hasPrefix:@"fastq"]) {
        qualityMin = _qualityLimitsForFastq[_outputFormatSelector.title.UTF8String].first;
        qualityMax = _qualityLimitsForFastq[_outputFormatSelector.title.UTF8String].second;
    }
    _qualityTextfield.stringValue = [NSString stringWithFormat:@"%c", qualityMax];
}

- (void)_updateEnabledCheckBoxes
{
    NSString *inputPathExtension = _inputFormatSelector.title;
    if ([_dataSource respondsToSelector:@selector(inputPathString)] &&
        ![[_dataSource inputPathString] isEqualToString:@"/"] &&
        [_inputFormatSelector.title isEqualToString:@"Use extension"])
    {
        inputPathExtension = [self _pathExtensionFromInputPathControl];
    }
    
    BOOL fastq = [_outputFormatSelector.title hasPrefix:@"fastq"];
    BOOL fasta = [_outputFormatSelector.title hasPrefix:@"fasta"];
    BOOL csv_tsv_output = [_outputFormatSelector.title isEqualToString:@"csv"] ||
                          [_outputFormatSelector.title isEqualToString:@"tsv"];
    BOOL csv_tsv_input = [inputPathExtension hasPrefix:@"csv"] ||
                         [inputPathExtension hasPrefix:@"tsv"];
    
    // csv/tsv
    _omitQualityCheckbox.hidden = !csv_tsv_output;
    _reorderOutputColumnsCheckbox.hidden = !csv_tsv_output;
    _columnsOutputOrderTextField.hidden = !csv_tsv_output;
    _columnsInputOrderTextField.hidden = !csv_tsv_input;
    _reorderInputColumnsCheckbox.hidden = !csv_tsv_input;
    // fasta
    _splitFastaCheckbox.hidden = !fasta;
    // fastq
    _defaultQualityCheckbox.hidden = !fastq;
    _duplicateFastqIdsCheckbox.hidden = !fastq;
    _qualityTextfield.hidden = !fastq;

    _ignoreColumnDefsCheckbox.hidden = !([inputPathExtension hasPrefix:@"csv"] ||
                                         [inputPathExtension hasPrefix:@"tsv"]);
    [self _updateFastqOutputQuality];
}

- (NSString *)_pathExtensionFromInputPathControl
{
    if ([[_dataSource inputPathString].pathExtension isEqualToString:@"gz"])
        return [[[_dataSource inputPathString] stringByDeletingPathExtension] pathExtension];
    
    return [_dataSource inputPathString].pathExtension;
}

@end

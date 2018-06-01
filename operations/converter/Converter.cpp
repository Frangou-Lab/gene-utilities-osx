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

#include <chrono>

#include "Converter.hpp"
#include <libgene/utils/StringUtils.hpp>
#include <libgene/utils/CppUtils.hpp>
#include <libgene/def/Flags.hpp>
#include <libgene/file/alignment/sam/SamRecord.hpp>
#include <libgene/file/alignment/AlignmentFile.hpp>
#include <libgene/file/sequence/SequenceFile.hpp>
#include <libgene/file/sequence/SequenceRecord.hpp>
#include <libgene/log/Logger.hpp>

template <int ThrottleCount = 1024>
bool HasToUpdateProgress_(int64_t count)
{
    return (count % ThrottleCount) == 0;
}

Converter::Converter(const std::vector<std::string>& input_paths,
                     const std::string& output_path,
                     std::unique_ptr<gene::CommandLineFlags>&& flags)
: flags_(std::move(flags)), inputPaths(input_paths), outputFilePath(output_path), totalSizeInBytes(0)
{
    bool hasInputFormatSet = (flags_->GetSetting(gene::Flags::kInputFormat) != nullptr);
    auto outputFormat = *flags_->GetSetting(gene::Flags::kOutputFormat);
    bool fastqWithScale = (outputFormat.find("fastq") != std::string::npos &&
                           outputFormat != "fastq");
    
    bool fastqInputFormat = false;
    if (hasInputFormatSet) {
        fastqInputFormat = flags_->GetSetting(gene::Flags::kInputFormat)->find("fastq") !=
                           std::string::npos;
    }
    fastqFormatConversion = hasInputFormatSet && fastqInputFormat && fastqWithScale;
    if (fastqFormatConversion) {
        auto inputFormat = *flags_->GetSetting(gene::Flags::kInputFormat);
        inputFastqVariant = gene::utils::FormatNameToVariant(inputFormat);
        outputFastqVariant = gene::utils::FormatNameToVariant(outputFormat);
    }
}

bool Converter::Init_()
{
    for (const auto& filePath: inputPaths) {
        auto extension = gene::utils::GetExtension(filePath);
        gene::FileType type = gene::utils::str2type(extension);
        
        if (type != gene::FileType::Sam && type != gene::FileType::Bam) {
            auto inFile = gene::SequenceFile::FileWithName(filePath, flags_, gene::OpenMode::Read);
            if (inFile) {
                totalSizeInBytes += inFile->length();
                sequence_input_files_.push_back(std::move(inFile));
            }
        } else {
            auto inFile = gene::AlignmentFile::FileWithName(filePath, flags_, gene::OpenMode::Read);
            if (inFile) {
                totalSizeInBytes += inFile->length();
                alignment_input_files_.push_back(std::move(inFile));
            }
        }
    }
    
    if (!((sequence_input_files_.empty() || sequence_input_files_[0]->isValidGeneFile()) &&
          (alignment_input_files_.empty() || alignment_input_files_[0]->isValidAlignmentFile()))) {
        PrintfLog("Input file has an invalid format\n");
        return false;
    }
    
    if (outputFilePath.empty()) {
        outputFilePath = gene::utils::ConstructOutputNameWithFile(inputPaths.front(),
                                                            gene::FileType::Unknown,
                                                            outputFilePath,
                                                            flags_,
                                                            "-converted");
    }
    
    if (!(output_file_ = gene::SequenceFile::FileWithName(outputFilePath, flags_, gene::OpenMode::Write))) {
        PrintfLog("Can't create output file\n");
        return false;
    }
    return true;
}

bool Converter::Process()
{
    if (!Init_()) {
        PrintfLog("Can't proceed further. Aborting operation.");
        return false;
    }

    if (flags_->verbose && !sequence_input_files_.empty()) {
        PrintfLog("Converting %s(%s) -> %s(%s)\n", sequence_input_files_[0]->filePath().c_str(),
               sequence_input_files_[0]->strFileType().c_str(), output_file_->filePath().c_str(),
               output_file_->strFileType().c_str());
    }
    
    gene::SequenceRecord record;
    auto start = std::chrono::high_resolution_clock::now();
    int64_t counter = 0;
    int64_t bytesProcessed = 0;

    for (const auto& input_file : sequence_input_files_) {
        while (!(record = input_file->Read()).Empty()) {
            if (HasToUpdateProgress_(counter) && update_progress_callback) {
                bool hasToCancelOperation = update_progress_callback((input_file->position() + bytesProcessed)/static_cast<float>(totalSizeInBytes*100.0));
                if (hasToCancelOperation)
                    return true;
            }
            
            ++counter;
            if (fastqFormatConversion)
                record.ShiftQuality(inputFastqVariant, outputFastqVariant);
            
            output_file_->Write(record);
        }
        bytesProcessed += input_file->length();
    }
    
    gene::SamRecord samRecord;
    for (const auto& inputFile : alignment_input_files_) {
        while (!(samRecord = inputFile->read()).SEQ.empty()) {
            if (HasToUpdateProgress_(counter) && update_progress_callback) {
                bool hasToCancelOperation = update_progress_callback((inputFile->position() + bytesProcessed)/static_cast<float>(totalSizeInBytes*100.0));
                if (hasToCancelOperation)
                    return true;
            }
            
            ++counter;
            gene::SequenceRecord r{std::move(samRecord)};
            output_file_->Write(r);
        }
        bytesProcessed += inputFile->length();
    }
    
    if (counter == 0) {
        PrintfLog("Input file was either empty, or it had an incorrect format\n");
        return false;
    }
    
    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> secondsElapsed = end - start;
    
    if (flags_->verbose)
        PrintfLog("%ld records processed in %.2f seconds\n", counter, secondsElapsed.count());

    return true;
}

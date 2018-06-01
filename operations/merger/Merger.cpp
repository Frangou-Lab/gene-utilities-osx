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
#include <type_traits>

#include "Merger.hpp"
#include <libgene/log/Logger.hpp>
#include <libgene/file/sequence/SequenceFile.hpp>

template <int ThrottleCount = 1024>
bool HasToUpdateProgress_(int64_t count)
{
    return (count % ThrottleCount) == 0;
}

Merger::Merger(std::vector<std::string> input_paths,
               std::string output_path,
               std::unique_ptr<gene::CommandLineFlags>&& flags)
: flags_(std::move(flags)),
  inputFilePaths(input_paths),
  outputPath(output_path)
{
    
}

bool Merger::Init_()
{
    for (const auto& path : inputFilePaths) {
        auto in_file = gene::SequenceFile::FileWithName(path, flags_, gene::OpenMode::Read);
        if (!in_file) {
            PrintfLog("Can't open input file %s\n", path.c_str());
            break;
        }
        if (!in_file->isValidGeneFile()) {
            PrintfLog("Input file %s has an invalid format\n", path.c_str());
            break;
        }
        total_size_in_bytes_ += in_file->length();
        inputFiles.push_back(std::move(in_file));
    }
    
    if (!(outFile = gene::SequenceFile::FileWithName(outputPath, flags_, gene::OpenMode::Write))) {
        PrintfLog("Can't create output file\n");
        return false;
    }
    return true;
}

bool Merger::Process()
{
    if (!Init_()) {
        PrintfLog("Can't proceed further. Aborting operation.");
        return false;
    }
    
    if (flags_->verbose)
        PrintfLog("Merging into ->%s(%s)\n",
                  outFile->filePath().c_str(),
                  outFile->strFileType().c_str());
    
    auto start = std::chrono::high_resolution_clock::now();
    int64_t counter = 0;
    int64_t bytes_processed = 0;
    
    for (const auto& in_file : inputFiles) {
        if (flags_->verbose) {
            PrintfLog("Merging in <-%s(%s)\n",
                      in_file->filePath().c_str(),
                      in_file->strFileType().c_str());
        }

        gene::SequenceRecord record;
        while (!(record = in_file->Read()).Empty()) {
            ++counter;
            outFile->Write(record);
            
            if (HasToUpdateProgress_(counter) && update_progress_callback) {
                bool hasToCancelOperation = update_progress_callback((in_file->position() + bytes_processed)/static_cast<float>(total_size_in_bytes_*100.0));
                
                if (hasToCancelOperation)
                    return true;
            }
        }
        bytes_processed += in_file->length();
    }

    if (counter == 0) {
        PrintfLog("Input file was either empty, or it had an incorrect format\n");
        return false;
    }
    auto secondsElapsed = std::chrono::duration<double>(std::chrono::high_resolution_clock::now() - start);
    
    if (flags_->verbose)
        PrintfLog("%lld records processed in %.2f seconds\n", counter, secondsElapsed.count());
    
    return true;
}

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

#ifndef LIBGENE_OPERATIONS_CONVERTER_HPP_
#define LIBGENE_OPERATIONS_CONVERTER_HPP_

#include <vector>
#include <memory>
#include <string>
#include <functional>

#include <libgene/file/sequence/SequenceFile.hpp>
#include <libgene/file/alignment/AlignmentFile.hpp>
#include <libgene/flags/CommandLineFlags.hpp>
#include <libgene/def/FileType.hpp>

class Converter final {
 public:
    Converter(const std::vector<std::string>& input_paths,
              const std::string& output_path,
              std::unique_ptr<gene::CommandLineFlags>&& flags);
    bool Process();
    std::function<bool(float)> update_progress_callback;

 private:
    std::unique_ptr<gene::SequenceFile> output_file_;
    std::vector<std::unique_ptr<gene::SequenceFile>> sequence_input_files_;
    std::vector<std::unique_ptr<gene::AlignmentFile>> alignment_input_files_;
    std::unique_ptr<gene::CommandLineFlags> flags_;

    int64_t totalSizeInBytes;
    std::string outputFilePath;
    std::vector<std::string> inputPaths;
    bool fastqFormatConversion{false};
    gene::FastqVariant inputFastqVariant;
    gene::FastqVariant outputFastqVariant;
    bool Init_();
};

#endif  // LIBGENE_OPERATIONS_CONVERTER_HPP_

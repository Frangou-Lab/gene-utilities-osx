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

#ifndef LIBGENE_OPERATIONS_EXTRACTOR_HPP_
#define LIBGENE_OPERATIONS_EXTRACTOR_HPP_

#include "ExtractorJob.hpp"

#include <map>
#include <string>
#include <memory>
#include <mutex>
#include <cstdint>

#include <libgene/file/sequence/SequenceFile.hpp>
#include <libgene/flags/CommandLineFlags.hpp>

class Extractor {
 public:
    Extractor(ExtractorJob&& job);
    bool Process();
    std::function<bool(float)> update_progress_callback;

 private:
    typedef std::unique_ptr<gene::SequenceFile> SequenceFilePtr;
    // '.second' can be nullptr if the input files are not paired
    typedef std::pair<SequenceFilePtr, SequenceFilePtr> SequenceFilePtrsPair;
    typedef gene::SequenceRecord Record;
    typedef std::pair<Record, gene::SequenceRecord> SequenceRecordPair;

    std::unique_ptr<gene::CommandLineFlags> flags_;
    std::vector<SequenceFilePtrsPair> input_files_;

    SequenceFilePtr output_file_;
    std::map<std::string, SequenceFilePtrsPair> demultiplexed_output_files_;

    std::vector<std::string> queries_;
    int64_t total_size_in_bytes_{0};

    bool search_in_data_{false};
    bool solexa_variant_{false};
    bool demultiplex_input_{false};
    bool wildcard_search_{false};
    bool paired_demultiplexing_{false};
    bool illumina_r2_barcodes_{false};

    bool operation_cancelled_{false};

    int trim_length_;
    std::mutex write_mutex_;
    std::map<std::string, std::unique_ptr<std::mutex>> write_mutexes_;

    bool Init_();
    void FlushThreadLocalBuffer_(std::vector<gene::SequenceRecord>& buffer);
    void FlushThreadLocalBuffer_(const std::string& key,
                                 std::vector<SequenceRecordPair>& buffer);

    void MultipleOutputFilesExtract_(std::atomic<int64_t>& counter,
                                     std::atomic<int64_t>& extracted);
    void MultipleOutputPairedFilesExtract_(std::atomic<int64_t>& counter,
                                           std::atomic<int64_t>& extracted);
    void SingleOutputFileExtract_(std::atomic<int64_t>& counter,
                                  std::atomic<int64_t>& extracted);
};

#endif  // LIBGENE_OPERATIONS_EXTRACTOR_HPP_

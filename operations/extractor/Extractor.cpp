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

#include <thread>
#include <future>
#include <chrono>
#include <iostream>
#include <cassert>
#include <stdexcept>

#include "Extractor.hpp"
#include <libgene/utils/CppUtils.hpp>
#include <libgene/utils/StringUtils.hpp>
#include <libgene/search/WildcardMatcher.hpp>
#include <libgene/search/FuzzySearch.hpp>
#include <libgene/def/Flags.hpp>
#include <libgene/file/sequence/SequenceFile.hpp>
#include <libgene/log/Logger.hpp>
#include <libgene/def/Def.hpp>

using gene::Flags;
using gene::SequenceFile;
using gene::SequenceRecord;

constexpr int64_t kThreadLocalOutputBufferSize = 1024;

template <typename TaskT>
static void LaunchMultithreadedTask(TaskT& task, int files_count);

template <int ThrottleCount = 1024>
bool HasToUpdateProgress_(int64_t count)
{
    return (count % ThrottleCount) == 0;
}

Extractor::Extractor(ExtractorJob&& job)
: flags_(std::move(job.flags))
, queries_(std::move(job.queries))
{
    demultiplex_input_ = flags_->SettingExists(Flags::kDemultiplexByTags);
    illumina_r2_barcodes_ = flags_->SettingExists(Flags::kIlluminaR2Tags);
    
    if ((solexa_variant_ = flags_->SettingExists(Flags::kSolexaFastqCutoffLength))) {
        trim_length_ = flags_->GetIntSetting(Flags::kSolexaFastqCutoffLength);
        PrintfLog("Demultiplexing as Solexa FASTQ with trim length %i", trim_length_);
    }
    
    for (const auto& input_path_pair : job.input_paths) {
        auto r1_input_file = SequenceFile::FileWithName(input_path_pair.first,
                                                        flags_,
                                                        gene::OpenMode::Read);

        if (r1_input_file) {
            if (r1_input_file->fileKind() != gene::FileKind::SingleEnd)
                paired_demultiplexing_ = true;

            std::unique_ptr<SequenceFile> r2_input_file = nullptr;
            if (!input_path_pair.second.empty())
                r2_input_file = SequenceFile::FileWithName(input_path_pair.second,
                                                           flags_,
                                                           gene::OpenMode::Read);

            input_files_.push_back(std::make_pair(std::move(r1_input_file),
                                                  std::move(r2_input_file)));

            if (input_files_.back().second)
                total_size_in_bytes_ += input_files_.back().second->length();
            else
                total_size_in_bytes_ += input_files_.back().first->length();
        }
    }
    
    // There's no point in doing this special treatment for a single file
    paired_demultiplexing_ &= (!job.input_paths.empty() &&
                               !job.input_paths.front().second.empty());
    
    // Check for weird fastq special case in some Illumina raw sequencing files
    // follow a misleading structure not containing paired reads in _R1 & _R2
    // files. Oddly, in this case _R2 contains barcode used for that read.
    paired_demultiplexing_ &= !illumina_r2_barcodes_;
    
    auto IsWildcardQuery = [](const std::string& str)
    {
        return str.find('*') != std::string::npos ||
               str.find('?') != std::string::npos;
    };

    for (const auto& query : queries_)
        wildcard_search_ = wildcard_search_ || IsWildcardQuery(query);

    search_in_data_ = flags_->SettingExists(Flags::kTagIsInSequence);

    if (queries_.empty()) {
        PrintfLog("Can't search for empty set\n");
        throw std::runtime_error("Can't create output file\n");
    }

    if (demultiplex_input_) {
        DEBUG_ASSERT_(job.output_paths.size() == queries_.size() + 1,
                      "For each input index, there should be its corresponding output file.");

        for (int i = 1; i < job.output_paths.size(); ++i) {
            auto file_pair = std::make_pair(SequenceFile::FileWithName(job.output_paths[i].first, flags_, gene::OpenMode::Write),
                                            SequenceFile::FileWithName(job.output_paths[i].second, flags_, gene::OpenMode::Write));

            demultiplexed_output_files_[queries_[i - 1]] = std::move(file_pair);
        }
    }
}

void Extractor::MultipleOutputFilesExtract_(std::atomic<int64_t>& counter,
                                            std::atomic<int64_t>& extracted)
{
    std::atomic<int64_t> bytes_processed(0);
    bool enable_error_correction = flags_->SettingExists(Flags::kDemultiplexWithErrorCorrection);
    
    // Prepare mutexes for each file
    for (const auto& query : queries_)
        write_mutexes_.emplace(query, std::make_unique<std::mutex>());
    
    auto extractTask = [this, &counter, &extracted, &bytes_processed, enable_error_correction]
                       (const int start, const int end)
    {
        std::map<std::string, std::vector<std::pair<SequenceRecord, SequenceRecord>>> local_buffer;

        for (const auto& query : queries_) {
            std::vector<std::pair<SequenceRecord, SequenceRecord>> storage_for_key;
            storage_for_key.reserve(kThreadLocalOutputBufferSize);
            local_buffer.emplace(query, storage_for_key);
        }
        
        for (int64_t i = start; i < end; ++i) {
            auto& input_file_pair = input_files_[i];
            int64_t previous_offset_in_bytes = 0;

            int64_t read_iteration = 0;
            std::pair<SequenceRecord, SequenceRecord> record_pair;
            while (!(record_pair.first = input_file_pair.first->Read()).Empty()) {

                if (input_file_pair.second)
                    record_pair.second = input_file_pair.second->Read();

                counter++;
                read_iteration++;
                
                // Search
                for (const auto& q : queries_) {
                    bool keep_record = false;

                    if (solexa_variant_)
                        keep_record = record_pair.first.trimBarcodeSingleEnd(q, trim_length_, enable_error_correction);
                    else if (enable_error_correction)
                        keep_record = (gene::FuzzySearch::FindByHamming1(record_pair.first.desc, q) != std::string::npos);
                    else
                        keep_record = (gene::FuzzySearch::NAwareFind(record_pair.first.desc, q) != std::string::npos);
                    
                    if (keep_record) {
                        extracted++;
                        
                        auto& buffer_for_current_query = local_buffer[q];
                        buffer_for_current_query.emplace_back(std::move(record_pair));

                        if (buffer_for_current_query.size() >= kThreadLocalOutputBufferSize)
                            FlushThreadLocalBuffer_(q, buffer_for_current_query);
                    }
                }
                
                if (HasToUpdateProgress_<8192>(read_iteration) && update_progress_callback) {
                    int64_t current_position;
                    if (input_file_pair.second)
                       current_position = input_file_pair.second->position();
                    else
                        current_position = input_file_pair.first->position();

                    bytes_processed += current_position - previous_offset_in_bytes;
                    previous_offset_in_bytes = current_position;
                    
                    float currentProgress = bytes_processed/static_cast<float>(total_size_in_bytes_)*100;
                    bool hasToCancelOperation = update_progress_callback(currentProgress);
                    if (hasToCancelOperation) {
                        operation_cancelled_ = true;
                        i = end; // This will end the outermost loop
                        break;
                    }
                }
            }
        }
        for (auto& storage_with_key : local_buffer) {
            FlushThreadLocalBuffer_(storage_with_key.first,
                                    storage_with_key.second);
        }
    };
    LaunchMultithreadedTask(extractTask, static_cast<int>(input_files_.size()));
}

void Extractor::MultipleOutputPairedFilesExtract_(std::atomic<int64_t>& counter,
                                                  std::atomic<int64_t>& extracted)
{
    std::atomic<int64_t> bytes_processed(0);
    bool enable_error_correction = flags_->SettingExists(Flags::kDemultiplexWithErrorCorrection);
    
    // Prepare mutexes for each file
    for (const auto& query : queries_)
        write_mutexes_.emplace(query, std::make_unique<std::mutex>());
    
    std::atomic_bool cancel_everything(false);
    auto extractTask = [this, &counter, &extracted, &bytes_processed,
                        &cancel_everything, enable_error_correction]
                        (const int start, const int end) {
        std::map<std::string, std::vector<std::pair<SequenceRecord, SequenceRecord>>> local_buffer;

        for (const auto& query : queries_) {
            std::vector<std::pair<SequenceRecord, SequenceRecord>> storage_for_key;
            storage_for_key.reserve(kThreadLocalOutputBufferSize);
            local_buffer.emplace(query, storage_for_key);
        }
        
        for (int64_t i = start; i < end; ++i) {
            auto& [r1_input_file, r2_input_file] = input_files_[i];
            int64_t previous_offset_in_bytes = 0, read_iteration = 0;
            SequenceRecord barcode_record;

            while (!(barcode_record = r2_input_file->Read()).Empty()) {
                if (cancel_everything.load())
                    return;

                SequenceRecord read_record;
                read_record = r1_input_file->Read();

                counter++;
                read_iteration++;
                
                auto& barcode = barcode_record.seq;
                // Search
                for (const auto& q : queries_) {
                    bool keep_record = false;
                    if (enable_error_correction)
                        keep_record = (gene::FuzzySearch::FindByHamming1(barcode, q) != std::string::npos);
                    else
                        keep_record = (gene::FuzzySearch::NAwareFind(barcode, q) != std::string::npos);

                    if (keep_record) {
                        extracted++;
                        
                        std::string key = q;
                        if (paired_demultiplexing_)
                            assert(false && "not implemented");

                        if (read_record.name != barcode_record.name) {
                            PrintfLog("[ERROR] Found a pair of reads that don't correspond to each other:\nR1: %s\nR2: %s\nAborting.",
                                      read_record.name.c_str(),
                                      barcode_record.name.c_str());

                            operation_cancelled_ = true;
                            cancel_everything.store(true);
                            throw std::runtime_error("Found a pair of reads that don't correspond to each other");
                        }
                        auto& buffer_for_current_query = local_buffer[key];
                        if (buffer_for_current_query.size() >= kThreadLocalOutputBufferSize)
                            FlushThreadLocalBuffer_(key, buffer_for_current_query);

                        buffer_for_current_query.emplace_back(std::make_pair(std::move(read_record),
                                                                             std::move(barcode_record)));
                    }
                }
                
                if (HasToUpdateProgress_<8192>(read_iteration) && update_progress_callback) {
                    int64_t current_position = r2_input_file->position();
                    bytes_processed += current_position - previous_offset_in_bytes;
                    previous_offset_in_bytes = current_position;
                    
                    float currentProgress = bytes_processed/static_cast<float>(total_size_in_bytes_)*100;
                    bool hasToCancelOperation = update_progress_callback(currentProgress);
                    if (hasToCancelOperation) {
                        operation_cancelled_ = true;
                        i = end; // This will end the outermost loop
                        break;
                    }
                }
            }
        }
        for (auto& storage_with_key : local_buffer)
            FlushThreadLocalBuffer_(storage_with_key.first, storage_with_key.second);
    };
    LaunchMultithreadedTask(extractTask, static_cast<int>(input_files_.size()));
}

void Extractor::SingleOutputFileExtract_(std::atomic<int64_t>& counter,
                                         std::atomic<int64_t>& extracted)
{
    std::atomic<int64_t> bytes_processed(0);
    auto extractTask = [this, &counter, &extracted, &bytes_processed]
                       (const int start, const int end) {
        
        SequenceRecord record;
        std::vector<SequenceRecord> local_buffer;
        local_buffer.reserve(kThreadLocalOutputBufferSize);
        
        bool found = false;
        for (int64_t i = start; i < end; ++i) {
            auto& [input_file, r2_input_file] = input_files_[i];
            int64_t previous_offset_in_bytes = 0;
            int64_t read_iteration = 0;

            while (!(record = input_file->Read()).Empty()) {
                counter++;
                read_iteration++;
                
                if (HasToUpdateProgress_(read_iteration) && update_progress_callback) {
                    int64_t current_position = input_file->position();
                    bytes_processed += current_position - previous_offset_in_bytes;
                    previous_offset_in_bytes = current_position;
                    
                    bool hasToCancelOperation = update_progress_callback(bytes_processed/static_cast<float>(total_size_in_bytes_*100.0));
                    if (hasToCancelOperation) {
                        operation_cancelled_ = true;
                        i = end; // This will end the outermost loop.
                        break;
                    }
                }
                
                // Search
                found = false;
                for (const auto& q : queries_) {
                    if (wildcard_search_) {
                        if (search_in_data_ && (gene::WildcardMatcher::Match(q, record.seq) || record.seq.find(q) != std::string::npos))
                            found = true;
                        else {
                            std::string id_line = record.name + ' ' + record.desc;
                            found = (gene::WildcardMatcher::Match(q, id_line) ||
                                     id_line.find(q) != std::string::npos);
                        }
                    } else {
                        if (search_in_data_ && record.seq.find(q) != std::string::npos)
                            found = true;
                        else if ((record.name + ' ' + record.desc).find(q) != std::string::npos)
                            found = true;
                    }
                    if (found)
                        break;
                }
                
                if (found) {
                    extracted++;
                    if (local_buffer.size() >= kThreadLocalOutputBufferSize)
                        FlushThreadLocalBuffer_(local_buffer);

                    local_buffer.emplace_back(std::move(record));
                }
            }
        }
        FlushThreadLocalBuffer_(local_buffer);
    };
    LaunchMultithreadedTask(extractTask, static_cast<int>(input_files_.size()));
}

bool Extractor::Process()
{
    if (flags_->verbose) {
        std::string input_names;
        for (const auto& inFile : input_files_) {
            input_names.append(inFile.first->filePath() + '\n');
            if (inFile.second)
                input_names.append(inFile.second->filePath() + '\n');
        }
        
        std::string queries_string;
        for (int i = 0; i < queries_.size(); ++i) {
            queries_string.append("GF" +
                                  gene::utils::PaddedToLengthString(i + 1, 4) +
                                  "\t " +
                                  queries_[i] +
                                  '\n');
        }
        
        if (demultiplex_input_) {
            std::string output_names;
            for (const auto& out_file_pair : demultiplexed_output_files_) {
                if (out_file_pair.first.empty())
                    continue;

                output_names.append("->" + out_file_pair.second.first->filePath() + '\n');
                if (out_file_pair.second.second)
                    output_names.append("->" + out_file_pair.second.second->filePath() + '\n');
            }

            PrintfLog("Demultiplexing \n%s \n%s\n", input_names.c_str(), output_names.c_str());
        } else {
            std::string target = "sequences";
            if (!search_in_data_)
                target = "IDs";

            PrintfLog("Extracting from\n%s \u2517\u2192 %s(%s)%s \n%s containing:\n%s",
                       input_names.c_str(),
                       output_file_->filePath().c_str(),
                       output_file_->strFileType().c_str(),
                       search_in_data_ ? " (data search)" : "",
                       target.c_str(),
                       queries_string.c_str());
        }
    }
    
    std::atomic<int64_t> counter(0);
    std::atomic<int64_t> extracted(0);

    auto start = std::chrono::high_resolution_clock::now();
    if (illumina_r2_barcodes_)
        MultipleOutputPairedFilesExtract_(counter, extracted);
    else if (demultiplex_input_)
        MultipleOutputFilesExtract_(counter, extracted);
    else
        SingleOutputFileExtract_(counter, extracted);

    auto elapsed = std::chrono::high_resolution_clock::now() - start;

    if (counter == 0) {
        PrintfLog("Input file was either empty, or it had an incorrect format\n");
        return false;
    }

    if (flags_->verbose) {
        PrintfLog("%lld records processed in %lli seconds\n%lld records extracted\n", counter.load(),
                   std::chrono::duration_cast<std::chrono::seconds>(elapsed).count(), extracted.load());
    }
    return !operation_cancelled_;
}

void Extractor::FlushThreadLocalBuffer_(std::vector<SequenceRecord>& buffer)
{
    std::lock_guard<std::mutex> write_lock(write_mutex_);
    for (auto& r : buffer)
        output_file_->Write(r);

    buffer.clear();
}

void Extractor::FlushThreadLocalBuffer_(const std::string& key, std::vector<Extractor::SequenceRecordPair>& buffer)
{
    auto& mutex_for_key = write_mutexes_[key];
    std::lock_guard<std::mutex> lock(*mutex_for_key);
    auto& output_files_for_key = demultiplexed_output_files_[key];
    for (const auto& record_pair : buffer) {
        output_files_for_key.first->Write(record_pair.first);
        if (!record_pair.second.Empty())
            output_files_for_key.second->Write(record_pair.second);
    }

    buffer.clear();
}

template <typename TaskT>
static void LaunchMultithreadedTask(TaskT& task, int files_count)
{
    const int logical_cores = std::thread::hardware_concurrency();
    const int number_of_tasks = std::min(logical_cores*4, files_count);
    const int chunk_size = std::max(files_count/number_of_tasks, 1);
    
    std::vector<std::future<void>> tasks;
    tasks.reserve(number_of_tasks);
    for (int i = 0; i < number_of_tasks; ++i) {
        int64_t remainder = (i != (number_of_tasks - 1) ? 0 : files_count % number_of_tasks);
#ifdef DEBUG
        std::cerr << "Starting task: #" << i << " [" << i*chunk_size << ", " << (i + 1)*chunk_size + remainder << ")\n";
#endif  // DEBUG
        tasks.emplace_back(std::async(task,
                                      i*chunk_size,
                                      (i + 1)*chunk_size + remainder));
    }
    for (auto& task: tasks) {
        // Not calling 'get()' will cause any exception to be discarded.
        task.get();
    }
}

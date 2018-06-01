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

#ifndef ExtractorJob_hpp
#define ExtractorJob_hpp

#include <vector>
#include <string>
#include <memory>

#include <libgene/flags/CommandLineFlags.hpp>

struct ExtractorJob {
    ExtractorJob(std::vector<std::pair<std::string, std::string>> input_paths,
                 std::vector<std::pair<std::string, std::string>> output_paths,
                 std::unique_ptr<gene::CommandLineFlags>&& flags,
                 const std::vector<std::string>& queries)
    : input_paths(input_paths)
    , output_paths(output_paths)
    , flags(std::move(flags))
    , queries(queries)
    {
    }

    ExtractorJob(ExtractorJob &&other) noexcept
    {
        std::swap(flags, other.flags);
        std::swap(input_paths, other.input_paths);
        std::swap(output_paths, other.output_paths);
        std::swap(queries, other.queries);
    }

    std::unique_ptr<gene::CommandLineFlags> flags;
    std::vector<std::pair<std::string, std::string>> input_paths;
    std::vector<std::pair<std::string, std::string>> output_paths;
    std::vector<std::string> queries;
};

#endif /* ExtractorJob_hpp */

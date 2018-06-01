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

#include <string>
#include <iostream>

#import <XCTest/XCTest.h>

#include <libgene/search/FuzzySearch.hpp>

using gene::FuzzySearch;

@interface FuzzySearchUnitTests : XCTestCase

@end

@implementation FuzzySearchUnitTests

- (void)testFuzzySearch_HammingDistance1Search_T1
{
    std::vector<std::string> barcodes = {
        "AAGCCTA", "ACCGGTA", "AGTCGTA",
        "ATCAGCA", "CAGAACG", "CATAGCA",
        "CGAGGGT", "CGGGATG", "CTCTAGG",
        "CTGATGA", "CTTGACA", "GCTGATA",
        "GGATTCA", "GGGGGGG", "GTAGGCA",
        "TACGACA", "TGAAACA", "TGAATCA",
        "TTCGGCA"};
    
    for (int i = 0; i < barcodes.size(); ++i) {
        for (int j = i + 1; j < barcodes.size(); ++j) {
            int64_t position = FuzzySearch::FindByHamming1(barcodes[i],
                                                           barcodes[j]);
            XCTAssert(position == std::string::npos || (i == 16 && j == 17));
        }
    }
}

- (void)testFuzzySearch_HammingDistance1Search_T2
{
    std::vector<std::string> barcodes = {
        "AAGCCTA", "ACCGGTA", "AGTCGTA",
        "ATCAGCA", "CAGAACG", "CATAGCA",
        "CGAGGGT", "CGGGATG", "CTCTAGG",
        "CTGATGA", "CTTGACA", "GCTGATA",
        "GGATTCA", "GGGGGGG", "GTAGGCA",
        "TACGACA", "TGAAACA", "TGAATCA",
        "TTCGGCA"};
    
    for (int i = 0; i < barcodes.size(); ++i) {
        for (int j = i + 1; j < barcodes.size(); ++j) {
            int64_t position = FuzzySearch::FindByHamming1(barcodes[i],
                                                           barcodes[j]);
            XCTAssert(position == std::string::npos || (i == 16 && j == 17));
        }
    }
}

- (void)testFuzzySearch_NAwareFind
{
    XCTAssert(FuzzySearch::NAwareFind("AATTG", "ATNN") == 1);
    XCTAssert(FuzzySearch::NAwareFind("HTAGG", "NBT") == std::string::npos);
    XCTAssert(FuzzySearch::NAwareFind("ABCDE", "E") == 4);
    XCTAssert(FuzzySearch::NAwareFind("ABCDE", "N") == 0);
    XCTAssert(FuzzySearch::NAwareFind("ABCDE", "F") == std::string::npos);
    XCTAssert(FuzzySearch::NAwareFind("AAGCCTA", "AAGCCTN") == 0);
    XCTAssert(FuzzySearch::NAwareFind("AAGCCT", "AAGCCTN") == std::string::npos);
}

- (void)testHammingDistance1Performance
{
    // This is an example of a performance test case.
    [self measureBlock:^{
        std::vector<std::string> barcodes = {
            "AAGCCTA", "ACCGGTA", "AGTCGTA",
            "ATCAGCA", "CAGAACG", "CATAGCA",
            "CGAGGGT", "CGGGATG", "CTCTAGG",
            "CTGATGA", "CTTGACA", "GCTGATA",
            "GGATTCA", "GGGGGGG", "GTAGGCA",
            "NNNNNNN", "TACGACA", "TGAAACA",
            "TGAATCA", "TTCGGCA"};
        
        for (int i = 0; i < barcodes.size(); ++i) {
            for (int j = i + 1; j < barcodes.size(); ++j) {
                int64_t position = FuzzySearch::FindByHamming1(barcodes[i],
                                                               barcodes[j]);
                std::cout << position;
            }
        }
    }];
}

@end

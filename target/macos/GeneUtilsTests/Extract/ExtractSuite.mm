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

#import <XCTest/XCTest.h>

#include <memory>
#include <string>
#include <fstream>

#include "Extractor.hpp"

#include <libgene/def/Flags.hpp>

using gene::Flags;

@interface ExtractSuite : XCTestCase
{
    std::string projectDir;
    std::string projectTestsDir;
    std::string testSuiteDir;
}

@end

@implementation ExtractSuite

- (void)setUp
{
    [super setUp];
    projectDir = std::getenv("PROJECT_DIR");
    projectTestsDir = projectDir + "/GeneUtilsTests";
    testSuiteDir = projectTestsDir + "/Extract";
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testDemultiplexOrdinaryFastqTest
{
    std::string testPath = testSuiteDir + "/DemultiplexOrdinaryFastq";
    std::vector<std::pair<std::string, std::string>> inputPath = {{testPath + "/IlluminaSimpleInput.fastq", ""}};
    std::string outputPath = testPath + "/IlluminaSimpleInput-extracted";
    std::string outputPath1, outputPath2, outputPath3;
    
    auto flags = std::make_unique<gene::CommandLineFlags>();
    // '-d'  – demultiplex
    flags->SetSetting(gene::Flags::kDemultiplexByTags, "");
    
    std::vector<std::string> queries = {"ATTCAGAN", "GAATTCGN", "TCCGGAAA"};
    
    std::vector<std::pair<std::string, std::string>> outputPaths = {{"some_fake_dir", ""}};
    for (const auto& query : queries) {
        outputPaths.push_back({outputPath + "_" + query + ".fastq", ""});
    }

    ExtractorJob job(inputPath, outputPaths, std::move(flags), queries);

    auto extractor = std::make_unique<Extractor>(std::move(job));
    XCTAssert(extractor->Process(), "FAIL. Converter 'process' returned false.");
    extractor = nullptr;
    
    // Check that the output matches
    outputPath1 = testPath + "/IlluminaSimpleInput-extracted_ATTCAGAN.fastq";
    outputPath2 = testPath + "/IlluminaSimpleInput-extracted_GAATTCGN.fastq";
    outputPath3 = testPath + "/IlluminaSimpleInput-extracted_TCCGGAAA.fastq";
    
    std::ifstream output1(outputPath1);
    std::ifstream output2(outputPath2);
    std::ifstream output3(outputPath3);
    
    if (!output1)
        XCTAssert(false, "Output file for barcode ATTCAGAN wasn't produced");
    
    if (!output2)
        XCTAssert(false, "Output file for barcode GAATTCGN wasn't produced");

    if (!output3)
        XCTAssert(false, "Output file for barcode TCCGGAAA wasn't produced");
    
    std::ifstream reference1Output(testPath + "/IlluminaSimpleReferenceOutput_ATTCAGAN.fastq");
    std::ifstream reference2Output(testPath + "/IlluminaSimpleReferenceOutput_GAATTCGN.fastq");
    std::ifstream reference3Output(testPath + "/IlluminaSimpleReferenceOutput_TCCGGAAA.fastq");
    if (!reference1Output)
        XCTAssert(false, "Could not open reference file for barcode CATTGCTG");

    std::string referenceLine, outputLine;
    bool outputIsEmpty = true;
    
    // Barcode: CATTGCTG
    while (std::getline(output1, outputLine))
    {
        XCTAssert(std::getline(reference1Output, referenceLine),
                  "Output file 1 is longer than expected");
        
        outputIsEmpty = false;
        if (outputLine != referenceLine)
            XCTAssert(false, "Lines don't match");
    }
    XCTAssert(!std::getline(reference1Output, referenceLine),
              "Output file 1 (Barcode: ATTCAGAN) is shorter than reference");
    XCTAssert(!outputIsEmpty, "Output file 1 was empty");
    reference1Output.close();
    
    // Barcode: TCATTACT
    while (std::getline(output2, outputLine)) {
        XCTAssert(std::getline(reference2Output, referenceLine),
                  "Output file 2 is longer than expected");
        
        outputIsEmpty = false;
        if (outputLine != referenceLine)
            XCTAssert(false, "Lines don't match");
    }
    XCTAssert(!std::getline(reference2Output, referenceLine),
              "Output file 2 (Barcode: GAATTCGN) is shorter than reference");
    XCTAssert(!outputIsEmpty, "Output file 2 was empty");
    reference2Output.close();
    
    // Barcode: TCATTGCT
    while (std::getline(output3, outputLine))
    {
        XCTAssert(std::getline(reference3Output, referenceLine),
                  "Output file 3 is longer than expected");
        
        outputIsEmpty = false;
        if (outputLine != referenceLine)
            XCTAssert(false, "Lines don't match");
    }
    XCTAssert(!std::getline(reference3Output, referenceLine),
              "Output file 3 (Barcode: TCCGGAAA) is shorter than reference");
    XCTAssert(!outputIsEmpty, "Output file 3 was empty");
    reference3Output.close();
    
    // Clean-up
    std::remove(outputPath1.c_str());
    std::remove(outputPath2.c_str());
    std::remove(outputPath3.c_str());
}

- (void)testDemultiplexSolexaFastQTest
{
    std::string testPath = testSuiteDir + "/DemultiplexSolexaFastq";
    std::string inputPath = testPath + "/SolexaSimpleInput.fastq";
    std::string outputPath = testPath + "/SolexaSimpleInput-extracted";
    std::string outputPath1, outputPath2, outputPath3;
    
    auto flags = std::make_unique<gene::CommandLineFlags>();
    // '-d'  – demultiplex
    flags->SetSetting(Flags::kDemultiplexByTags, "");
    
    // '-solexa-fastq-cutoff 35'
    flags->SetSetting(Flags::kSolexaFastqCutoffLength, "35");
    
    std::vector<std::string> queries = {"CATTGCTG", "TCATTACT", "TCATTGCT"};
    std::vector<std::pair<std::string, std::string>> outputPaths = {{"fake_dir", ""}};
    for (const auto& query : queries)
        outputPaths.push_back({outputPath + "_" + query + "_N35.fastq", ""});

    {
        ExtractorJob job({std::make_pair(inputPath, std::string())},
                         outputPaths,
                         std::move(flags),
                         queries);

        Extractor extractor(std::move(job));
        XCTAssert(extractor.Process(), "FAIL. Converter 'process' returned false.");
    }
    
    // Check that the output matches
    outputPath1 = testPath + "/SolexaSimpleInput-extracted_CATTGCTG_N35.fastq";
    outputPath2 = testPath + "/SolexaSimpleInput-extracted_TCATTACT_N35.fastq";
    outputPath3 = testPath + "/SolexaSimpleInput-extracted_TCATTGCT_N35.fastq";
    
    std::ifstream output1(outputPath1);
    std::ifstream output2(outputPath2);
    std::ifstream output3(outputPath3);
    
    if (!output1)
        XCTAssert(false, "Output file for barcode CATTGCTG wasn't produced");
    
    if (!output2)
        XCTAssert(false, "Output file for barcode TCATTACT wasn't produced");
    
    if (!output3)
        XCTAssert(false, "Output file for barcode TCATTGCT wasn't produced");
    
    std::ifstream reference1Output(testPath + "/SolexaSimpleReferenceOutput_CATTGCTG_N35.fastq");
    std::ifstream reference2Output(testPath + "/SolexaSimpleReferenceOutput_TCATTACT_N35.fastq");
    std::ifstream reference3Output(testPath + "/SolexaSimpleReferenceOutput_TCATTGCT_N35.fastq");
    
    if (!reference1Output)
        XCTAssert(false, "Could not open reference file for barcode CATTGCTG");
    
    std::string referenceLine, outputLine;
    bool outputIsEmpty = true;
    
    // Barcode: CATTGCTG
    while (std::getline(output1, outputLine)) {
        XCTAssert(std::getline(reference1Output, referenceLine),
                  "Output file 1 is longer than expected");
        
        outputIsEmpty = false;
        if (outputLine != referenceLine)
            XCTAssert(false, "Lines don't match");
    }
    XCTAssert(!std::getline(reference1Output, referenceLine),
              "Output file 1 (Barcode: CATTGCTG) is shorter than reference");
    XCTAssert(!outputIsEmpty, "Output file 1 was empty");
    reference1Output.close();
    
    // Barcode: TCATTACT
    while (std::getline(output2, outputLine)) {
        XCTAssert(std::getline(reference2Output, referenceLine),
                  "Output file 2 is longer than expected");
        
        outputIsEmpty = false;
        if (outputLine != referenceLine)
            XCTAssert(false, "Lines don't match");
    }
    XCTAssert(!std::getline(reference2Output, referenceLine),
              "Output file 2 (Barcode: TCATTACT) is shorter than reference");
    XCTAssert(!outputIsEmpty, "Output file 2 was empty");
    reference2Output.close();
    
    // Barcode: TCATTGCT
    while (std::getline(output3, outputLine)) {
        XCTAssert(std::getline(reference3Output, referenceLine),
                  "Output file 3 is longer than expected");
        
        outputIsEmpty = false;
        if (outputLine != referenceLine)
            XCTAssert(false, "Lines don't match");
    }
    XCTAssert(!std::getline(reference3Output, referenceLine),
              "Output file 3 (Barcode: TCATTGCT) is shorter than reference");
    XCTAssert(!outputIsEmpty, "Output file 3 was empty");
    reference3Output.close();
    
    // Clean-up
    std::remove(outputPath1.c_str());
    std::remove(outputPath2.c_str());
    std::remove(outputPath3.c_str());
}

- (void)testPerformance
{
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end

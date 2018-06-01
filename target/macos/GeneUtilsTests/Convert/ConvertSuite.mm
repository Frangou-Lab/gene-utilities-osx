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

#include "Converter.hpp"
#include <libgene/def/Flags.hpp>

#include <memory>
#include <string>
#include <fstream>

using namespace std::string_literals;

using gene::Flags;

@interface ConvertSuite : XCTestCase
{
    std::string projectDir;
    std::string projectTestsDir;
    std::string testSuiteDir;
}

@end

@implementation ConvertSuite

- (void)setUp
{
    [super setUp];
    projectDir = std::getenv("PROJECT_DIR");
    projectTestsDir = projectDir + "/GeneUtilsTests";
    testSuiteDir = projectTestsDir + "/Convert";
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testFastqIllumina1_3ToFastqIllumina1_8Conversion
{
    std::string testPath = testSuiteDir + "/FastqIllumina1_3ToFastqIllumina1_8";
    std::vector<std::string> inputPath = {testPath + "/Illumina1_3Input.fastq"};
    std::string outputPath = "";
    
    auto flags = std::make_unique<gene::CommandLineFlags>();
    flags->SetSetting("i", "fastq-"s + Flags::kIllumina1_3Suffix);
    flags->SetSetting("o", "fastq-"s + Flags::kIllumina1_8Suffix);
    
    auto converter = std::make_unique<Converter>(inputPath, outputPath, std::move(flags));
    XCTAssert(converter->Process(), "FAIL. Converter 'process' returned false.");
    converter = nullptr;
    
    // Check that the output matches
    outputPath = testPath + "/Illumina1_3Input-converted.fastq";
    std::ifstream output(outputPath);
    XCTAssert(output, "Output file wasn't produced");
    
    std::ifstream referenceOutput(testPath + "/Illumina1_8ReferenceOutput.fastq");
    XCTAssert(referenceOutput, "Could not open reference file");
    
    std::string referenceLine, outputLine;
    bool outputIsEmpty = true;
    while (std::getline(output, outputLine)) {
        outputIsEmpty = false;
        XCTAssert(std::getline(referenceOutput, referenceLine),
                  "Output file is longer than expected");
        XCTAssert(outputLine == referenceLine, "Lines don't match");
    }
    
    XCTAssert(!std::getline(referenceOutput, referenceLine),
              "Output file is shorter than reference");
    XCTAssert(!outputIsEmpty, "Output file was empty");
    
    referenceOutput.close();
    output.close();
    
    // Clean-up
    std::remove(outputPath.c_str());
}

- (void)testFastqIllumina1_3ToFastqSangerConversion
{
    std::string testPath = testSuiteDir + "/FastqIllumina1_3ToFastqSanger";
    std::vector<std::string> inputPath = {testPath + "/Illumina1_3Input.fastq"};
    std::string outputPath = "";
    
    auto flags = std::make_unique<gene::CommandLineFlags>();
    flags->SetSetting("i", "fastq-"s + Flags::kIllumina1_3Suffix);
    flags->SetSetting("o", "fastq-"s + Flags::kSangerSuffix);
    
    auto converter = std::make_unique<Converter>(inputPath, outputPath, std::move(flags));
    XCTAssert(converter->Process(), "FAIL. Converter 'process' returned false.");
    converter = nullptr;
    
    // Check that the output matches
    outputPath = testPath + "/Illumina1_3Input-converted.fastq";
    std::ifstream output(outputPath);
    XCTAssert(output, "Output file wasn't produced");
    
    std::ifstream referenceOutput(testPath + "/SangerReferenceOutput.fastq");
    XCTAssert(referenceOutput, "Could not open reference file");
    
    std::string referenceLine, outputLine;
    bool outputIsEmpty = true;
    while (std::getline(output, outputLine)) {
        outputIsEmpty = false;
        XCTAssert(std::getline(referenceOutput, referenceLine),
                  "Output file is longer than expected");
        XCTAssert(outputLine == referenceLine, "Lines don't match");
    }
    
    XCTAssert(!std::getline(referenceOutput, referenceLine),
              "Output file is shorter than reference");
    XCTAssert(!outputIsEmpty, "Output file was empty");
    
    referenceOutput.close();
    output.close();
    
    // Clean-up
    std::remove(outputPath.c_str());
}

- (void)testFastqIllumina1_8ToFastqIllumina1_3Conversion
{
    std::string testPath = testSuiteDir + "/FastqIllumina1_8ToFastqIllumina1_3";
    std::vector<std::string> inputPath = {testPath + "/Illumina1_8Input.fastq"};
    std::string outputPath = "";
    
    auto flags = std::make_unique<gene::CommandLineFlags>();
    flags->SetSetting("i", "fastq-"s + Flags::kIllumina1_8Suffix);
    flags->SetSetting("o", "fastq-"s + Flags::kIllumina1_3Suffix);
    
    auto converter = std::make_unique<Converter>(inputPath, outputPath, std::move(flags));
    XCTAssert(converter->Process(), "FAIL. Converter 'process' returned false.");
    converter = nullptr;
    
    // Check that the output matches
    outputPath = testPath + "/Illumina1_8Input-converted.fastq";
    std::ifstream output(outputPath);
    XCTAssert(output, "Output file wasn't produced");
    
    std::ifstream referenceOutput(testPath + "/Illumina1_3ReferenceOutput.fastq");
    XCTAssert(referenceOutput, "Could not open reference file");
    
    std::string referenceLine, outputLine;
    bool outputIsEmpty = true;
    while (std::getline(output, outputLine)) {
        outputIsEmpty = false;
        XCTAssert(std::getline(referenceOutput, referenceLine),
                  "Output file is longer than expected");
        XCTAssert(outputLine == referenceLine, "Lines don't match");
    }
    
    XCTAssert(!std::getline(referenceOutput, referenceLine),
              "Output file is shorter than reference");
    XCTAssert(!outputIsEmpty, "Output file was empty");
    
    referenceOutput.close();
    output.close();
    
    // Clean-up
    std::remove(outputPath.c_str());
}

- (void)testSangerToFastqIllumina1_3Conversion
{
    std::string testPath = testSuiteDir + "/SangerToFastqIllumina1_3";
    std::vector<std::string> inputPath = {testPath + "/SangerInput.fastq"};
    std::string outputPath = "";
    
    auto flags = std::make_unique<gene::CommandLineFlags>();
    flags->SetSetting("i", "fastq-"s + Flags::kSangerSuffix);
    flags->SetSetting("o", "fastq-"s + Flags::kIllumina1_3Suffix);
    
    auto converter = std::make_unique<Converter>(inputPath, outputPath, std::move(flags));
    XCTAssert(converter->Process(), "FAIL. Converter 'process' returned false.");
    converter = nullptr;
    
    // Check that the output matches
    outputPath = testPath + "/SangerInput-converted.fastq";
    std::ifstream output(outputPath);
    XCTAssert(output, "Output file wasn't produced");
    
    std::ifstream referenceOutput(testPath + "/Illumina1_3ReferenceOutput.fastq");
    XCTAssert(referenceOutput, "Could not open reference file");
    
    std::string referenceLine, outputLine;
    bool outputIsEmpty = true;
    while (std::getline(output, outputLine)) {
        outputIsEmpty = false;
        XCTAssert(std::getline(referenceOutput, referenceLine),
                  "Output file is longer than expected");
        XCTAssert(outputLine == referenceLine, "Lines don't match");
    }
    
    XCTAssert(!std::getline(referenceOutput, referenceLine),
              "Output file is shorter than reference");
    XCTAssert(!outputIsEmpty, "Output file was empty");
    
    referenceOutput.close();
    output.close();
    
    // Clean-up
    std::remove(outputPath.c_str());
}

- (void)testSangerToFastqIllumina1_8Conversion
{
    std::string testPath = testSuiteDir + "/SangerToFastqIllumina1_8";
    std::vector<std::string> inputPath = {testPath + "/SangerInput.fastq"};
    std::string outputPath = "";
    
    auto flags = std::make_unique<gene::CommandLineFlags>();
    flags->SetSetting("i", "fastq-"s + Flags::kSangerSuffix);
    flags->SetSetting("o", "fastq-"s + Flags::kIllumina1_8Suffix);
    
    auto converter = std::make_unique<Converter>(inputPath, outputPath, std::move(flags));
    XCTAssert(converter->Process(), "FAIL. Converter 'process' returned false.");
    converter = nullptr;
    
    // Check that the output matches
    outputPath = testPath + "/SangerInput-converted.fastq";
    std::ifstream output(outputPath);
    XCTAssert(output, "Output file wasn't produced");
    
    std::ifstream referenceOutput(testPath + "/Illumina1_8ReferenceOutput.fastq");
    XCTAssert(referenceOutput, "Could not open reference file");
    
    std::string referenceLine, outputLine;
    bool outputIsEmpty = true;
    while (std::getline(output, outputLine)) {
        outputIsEmpty = false;
        XCTAssert(std::getline(referenceOutput, referenceLine),
                  "Output file is longer than expected");
        XCTAssert(outputLine == referenceLine, "Lines don't match");
    }
    
    XCTAssert(!std::getline(referenceOutput, referenceLine),
              "Output file is shorter than reference");
    XCTAssert(!outputIsEmpty, "Output file was empty");
    
    referenceOutput.close();
    output.close();
    
    // Clean-up
    std::remove(outputPath.c_str());
}

- (void)testIllumina1_8ToFastqSangerConversion
{
    std::string testPath = testSuiteDir + "/FastqIllumina1_8ToFastqSanger";
    std::vector<std::string> inputPath = {testPath + "/Illumina1_8Input.fastq"};
    std::string outputPath = "";
    
    auto flags = std::make_unique<gene::CommandLineFlags>();
    flags->SetSetting("i", "fastq-"s + Flags::kIllumina1_8Suffix);
    flags->SetSetting("o", "fastq-"s + Flags::kSangerSuffix);
    
    auto converter = std::make_unique<Converter>(inputPath, outputPath, std::move(flags));
    XCTAssert(converter->Process(), "FAIL. Converter 'process' returned false.");
    converter = nullptr;
    
    // Check that the output matches
    outputPath = testPath + "/Illumina1_8Input-converted.fastq";
    std::ifstream output(outputPath);
    XCTAssert(output, "Output file wasn't produced");
    
    std::ifstream referenceOutput(testPath + "/SangerReferenceOutput.fastq");
    XCTAssert(referenceOutput, "Could not open reference file");
    
    std::string referenceLine, outputLine;
    bool outputIsEmpty = true;
    while (std::getline(output, outputLine)) {
        outputIsEmpty = false;
        XCTAssert(std::getline(referenceOutput, referenceLine),
                  "Output file is longer than expected");
        XCTAssert(outputLine == referenceLine, "Lines don't match");
    }
    
    XCTAssert(!std::getline(referenceOutput, referenceLine),
              "Output file is shorter than reference");
    XCTAssert(!outputIsEmpty, "Output file was empty");
    
    referenceOutput.close();
    output.close();
    
    // Clean-up
    std::remove(outputPath.c_str());
}

- (void)testSolexaToFastqIllumina1_8Conversion
{
    std::string testPath = testSuiteDir + "/FastqSolexaToFastqIllumina1_8";
    std::vector<std::string> inputPath = {testPath + "/SolexaInput.fastq"};
    std::string outputPath = "";
    
    auto flags = std::make_unique<gene::CommandLineFlags>();
    flags->SetSetting("i", "fastq-"s + Flags::kSolexaSuffix);
    flags->SetSetting("o", "fastq-"s + Flags::kIllumina1_8Suffix);
    
    auto converter = std::make_unique<Converter>(inputPath, outputPath, std::move(flags));
    XCTAssert(converter->Process(), "FAIL. Converter 'process' returned false.");
    converter = nullptr;
    
    // Check that the output matches
    outputPath = testPath + "/SolexaInput-converted.fastq";
    std::ifstream output(outputPath);
    XCTAssert(output, "Output file wasn't produced");
    
    std::ifstream referenceOutput(testPath + "/Illumina1_8ReferenceOutput.fastq");
    XCTAssert(referenceOutput, "Could not open reference file");
    
    std::string referenceLine, outputLine;
    bool outputIsEmpty = true;
    while (std::getline(output, outputLine)) {
        outputIsEmpty = false;
        XCTAssert(std::getline(referenceOutput, referenceLine),
                  "Output file is longer than expected");
        XCTAssert(outputLine == referenceLine, "Lines don't match");
    }
    
    XCTAssert(!std::getline(referenceOutput, referenceLine),
              "Output file is shorter than reference");
    XCTAssert(!outputIsEmpty, "Output file was empty");
    
    referenceOutput.close();
    output.close();
    // Clean-up
    std::remove(outputPath.c_str());
}

- (void)testSolexaToFastqIllumina1_3Conversion
{
    std::string testPath = testSuiteDir + "/FastqSolexaToFastqIllumina1_3";
    std::vector<std::string> inputPath = {testPath + "/SolexaInput.fastq"};
    std::string outputPath = "";
    
    auto flags = std::make_unique<gene::CommandLineFlags>();
    flags->SetSetting("i", "fastq-"s + Flags::kSolexaSuffix);
    flags->SetSetting("o", "fastq-"s + Flags::kIllumina1_3Suffix);
    
    auto converter = std::make_unique<Converter>(inputPath, outputPath, std::move(flags));
    XCTAssert(converter->Process(), "FAIL. Converter 'process' returned false.");
    converter = nullptr;
    
    // Check that the output matches
    outputPath = testPath + "/SolexaInput-converted.fastq";
    std::ifstream output(outputPath);
    XCTAssert(output, "Output file wasn't produced");
    
    std::ifstream referenceOutput(testPath + "/Illumina1_3ReferenceOutput.fastq");
    XCTAssert(referenceOutput, "Could not open reference file");
    
    std::string referenceLine, outputLine;
    bool outputIsEmpty = true;
    while (std::getline(output, outputLine)) {
        outputIsEmpty = false;
        XCTAssert(std::getline(referenceOutput, referenceLine),
                  "Output file is longer than expected");
        XCTAssert(outputLine == referenceLine, "Lines don't match");
    }
    
    XCTAssert(!std::getline(referenceOutput, referenceLine),
              "Output file is shorter than reference");
    XCTAssert(!outputIsEmpty, "Output file was empty");
    
    referenceOutput.close();
    output.close();
    // Clean-up
    std::remove(outputPath.c_str());
}

- (void)testFastQToFastaConversion
{
    std::string testPath = testSuiteDir + "/FastqToFasta";
    std::vector<std::string> inputPath = {testPath + "/IlluminaSimpleInput.fastq"};
    std::string outputPath = "";
    
    auto flags = std::make_unique<gene::CommandLineFlags>();
    flags->SetSetting("o", "fasta");
    
    auto converter = std::make_unique<Converter>(inputPath, outputPath, std::move(flags));
    XCTAssert(converter->Process(), "FAIL. Converter 'process' returned false.");
    converter = nullptr;
    
    // Check that the output matches
    outputPath = testPath + "/IlluminaSimpleInput-converted.fasta";
    std::ifstream output(outputPath);
    XCTAssert(output, "Output file wasn't produced");
    
    std::ifstream referenceOutput(testPath + "/IlluminaSimpleReferenceOutput.fasta");
    XCTAssert(referenceOutput, "Could not open reference file");
    
    std::string referenceLine, outputLine;
    bool outputIsEmpty = true;
    while (std::getline(output, outputLine)) {
        outputIsEmpty = false;
        XCTAssert(std::getline(referenceOutput, referenceLine),
                  "Output file is longer than expected");
        XCTAssert(outputLine == referenceLine, "Lines don't match");
    }
    
    XCTAssert(!std::getline(referenceOutput, referenceLine),
              "Output file is shorter than reference");
    XCTAssert(!outputIsEmpty, "Output file was empty");
    
    referenceOutput.close();
    output.close();
    
    // Clean-up
    std::remove(outputPath.c_str());
}

- (void)testQuotedCsvToFastQConversion
{
    std::string testPath = testSuiteDir + "/QuotedCsvToFastq";
    std::vector<std::string> inputPath = {testPath + "/QuotedCsvSimpleInput.csvc"};
    std::string outputPath = "";
    
    auto flags = std::make_unique<gene::CommandLineFlags>();
    flags->SetSetting("o", "fastq");
    
    auto converter = std::make_unique<Converter>(inputPath, outputPath, std::move(flags));
    XCTAssert(converter->Process(), "FAIL. Converter 'process' returned false.");
    converter = nullptr;
    
    // Check that the output matches
    outputPath = testPath + "/QuotedCsvSimpleInput-converted.fastq";
    std::ifstream output(outputPath);
    XCTAssert(output, "Output file wasn't produced");
    
    std::ifstream referenceOutput(testPath + "/QuotedFastQSimpleReferenceOutput.fastq");
    XCTAssert(referenceOutput, "Could not open reference file");
    
    std::string referenceLine, outputLine;
    bool outputIsEmpty = true;
    while (std::getline(output, outputLine)) {
        outputIsEmpty = false;
        XCTAssert(std::getline(referenceOutput, referenceLine),
                  "Output file is longer than expected");
        XCTAssert(outputLine == referenceLine, "Lines don't match");
    }
    
    XCTAssert(!std::getline(referenceOutput, referenceLine),
              "Output file is shorter than reference");
    XCTAssert(!outputIsEmpty, "Output file was empty");
    
    referenceOutput.close();
    output.close();
    
    // Clean-up
    std::remove(outputPath.c_str());
}

- (void)testQuotedWithQuotesInsideCsvToFastQConversion
{
    std::string testPath = testSuiteDir + "/QuotedCsvToFastq";
    std::vector<std::string> inputPath = {testPath + "/QuotedCsvWithQuotesInput.csvc"};
    std::string outputPath = "";
    
    auto flags = std::make_unique<gene::CommandLineFlags>();
    flags->SetSetting("o", "fastq");
    
    auto converter = std::make_unique<Converter>(inputPath, outputPath, std::move(flags));
    XCTAssert(converter->Process(), "FAIL. Converter 'process' returned false.");
    converter = nullptr;
    
    // Check that the output matches
    outputPath = testPath + "/QuotedCsvWithQuotesInput-converted.fastq";
    std::ifstream output(outputPath);
    XCTAssert(output, "Output file wasn't produced");
    
    std::ifstream referenceOutput(testPath + "/QuotedFastQWithQuotesReferenceOutput.fastq");
    XCTAssert(referenceOutput, "Could not open reference file");
    
    std::string referenceLine, outputLine;
    bool outputIsEmpty = true;
    
    while (std::getline(output, outputLine)) {
        outputIsEmpty = false;
        XCTAssert(std::getline(referenceOutput, referenceLine),
                  "Output file is longer than expected");
        XCTAssert(outputLine == referenceLine, "Lines don't match");
    }
    
    XCTAssert(!std::getline(referenceOutput, referenceLine),
              "Output file is shorter than reference");
    XCTAssert(!outputIsEmpty, "Output file was empty");
    
    referenceOutput.close();
    output.close();
    
    // Clean-up
    std::remove(outputPath.c_str());
}

- (void)testQuotedWithQuotesInsideTsvToFastQConversion
{
    std::string testPath = testSuiteDir + "/QuotedTsvToCsv";
    std::vector<std::string> inputPath = {testPath + "/QuotedTsvWithQuotesInput.tsvc"};
    std::string outputPath = "";
    
    auto flags = std::make_unique<gene::CommandLineFlags>();
    flags->SetSetting("o", "csv");
    
    auto converter = std::make_unique<Converter>(inputPath, outputPath, std::move(flags));
    XCTAssert(converter->Process(), "FAIL. Converter 'process' returned false.");
    converter = nullptr;
    
    // Check that the output matches
    outputPath = testPath + "/QuotedTsvWithQuotesInput-converted.csvc";
    std::string outputPathCtp = testPath + "/QuotedTsvWithQuotesInput-converted.ctp";
    std::ifstream output(outputPath);
    XCTAssert(output, "Output file wasn't produced");
    std::ifstream outputCtp(outputPathCtp);
    
    std::ifstream referenceOutput(testPath + "/QuotedTsvWithQuotesOutput.csvc");
    XCTAssert(referenceOutput, "Could not open reference file");
    std::ifstream referenceOutputCtp(testPath + "/QuotedTsvWithQuotesOutput.ctp");
    XCTAssert(referenceOutputCtp, "Could not open reference .ctp file");
    
    std::string referenceLine, outputLine;
    bool outputIsEmpty = true;
    while (std::getline(output, outputLine)) {
        outputIsEmpty = false;
        XCTAssert(std::getline(referenceOutput, referenceLine),
                  "Output file is longer than expected");
        XCTAssert(outputLine == referenceLine, "Lines don't match");
    }
    XCTAssert(!std::getline(referenceOutput, referenceLine),
              "Output file is shorter than reference");
    XCTAssert(!outputIsEmpty, "Output file was empty");
    
    while (std::getline(outputCtp, outputLine)) {
        outputIsEmpty = false;
        XCTAssert(std::getline(referenceOutputCtp, referenceLine),
                  "Output .ctp file is longer than expected");
        XCTAssert(outputLine == referenceLine, "Lines don't match");
    }
    XCTAssert(!std::getline(referenceOutputCtp, referenceLine),
              "Output .ctp file is shorter than reference");
    XCTAssert(!outputIsEmpty, "Output .ctp file was empty");
    
    referenceOutput.close();
    referenceOutputCtp.close();
    output.close();
    outputCtp.close();
    
    // Clean-up
    std::remove(outputPath.c_str());
    std::remove(outputPathCtp.c_str());
}

- (void)testNonQuotedCsvToFastQConversion
{
    std::string testPath = testSuiteDir + "/QuotedCsvToFastq";
    std::vector<std::string> inputPath = {testPath + "/NonQuotedCsvSimpleInput.csvc"};
    std::string outputPath = "";
    
    auto flags = std::make_unique<gene::CommandLineFlags>();
    flags->SetSetting("o", "fastq");
    
    auto converter = std::make_unique<Converter>(inputPath, outputPath, std::move(flags));
    XCTAssert(converter->Process(), "FAIL. Converter 'process' returned false.");
    converter = nullptr;
    
    // Check that the output matches
    outputPath = testPath + "/NonQuotedCsvSimpleInput-converted.fastq";
    std::ifstream output(outputPath);
    XCTAssert(output, "Output file wasn't produced");
    
    std::ifstream referenceOutput(testPath + "/NonQuotedFastQSimpleReferenceOutput.fastq");
    XCTAssert(referenceOutput, "Could not open reference file");
    
    std::string referenceLine, outputLine;
    bool outputIsEmpty = true;
    while (std::getline(output, outputLine))
    {
        outputIsEmpty = false;
        XCTAssert(std::getline(referenceOutput, referenceLine),
                  "Output file is longer than expected");
        XCTAssert(outputLine == referenceLine, "Lines don't match");
    }
    
    XCTAssert(!std::getline(referenceOutput, referenceLine),
              "Output file is shorter than reference");
    XCTAssert(!outputIsEmpty, "Output file was empty");
    
    referenceOutput.close();
    output.close();
    
    // Clean-up
    std::remove(outputPath.c_str());
}

- (void)testPerformance
{
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end

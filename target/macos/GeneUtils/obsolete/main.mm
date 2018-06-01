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

#import "CommandLineFlagsObj.h"
#import "Extractor.h"
#import "Mutator.h"

#include "Finder.hpp"
#include "CommandLineFlags.hpp"
#include "Converter.hpp"
#include "Merger.hpp"
#include "Splitter.hpp"

#include <string>
#include <vector>
#include <algorithm>

void help()
{
    printf("Gene Utilities v1.8.0 \
           \nBuild date %s\n", __DATE__);
#ifdef DEBUG
    printf("(debug)\n");
#else
    printf("\n");
#endif
    
    printf(
"\
Usage: geneutils <operation> [flags] <inputs> [outputs]\n\
Supported operations:\n\
  geneutils c(onvert) [flags] <input file> [output file] converts one file into another.\n\
  geneutils m(erge) [flags] <input file 1> [<input file 2>, ...] <output file> - merges several files into one.\n\
  geneutils s(plit) [flags] <input file> [output file] - splits one file into several.\n\
    -f <number of files> - split into this number of files; due to approximation actual number of files may differ a bit.\n\
    -r <number of records> - split into any number files but define maximum record numer for one file.\n\
    -sk <number of kilobytes> - split into any number files but define maximum size for one file. \n\
    -sm <number of megabytes> - the same\n\
  geneutils e(xtract) [flags] <input file> <output file> [<query1>, ...] - extracts subset\n\
    use <@filename> instead of <queryN> to read sequences from file\n\
    -s - search in data instead of IDs\n\
    -d - demultiplex input (for each query create a separate file containing records that match that query)\n\
    -solexa-fastq-cutoff <number of nucleotides> – search for barcodes in sequences extraction <number of nucleotedes> long sequnces \n\
  geneutils (m)u(tate) [flags] <reference file> <translation reference file> <mutation data file> - perform mutation\n\
  geneutils (f)ind [flags] <input file> <output file> [<query1>, ...] - generate a summary table of where <queryN> sequences are located in the input file\n\
    use <@filename> instead of <queryN> to read sequences from file\n\
    -c <N> - add N characters from upstream and downstream to search result\n\
    -m <N> - allow M characters to be different from the query sequence\n\
    -p - paired query extraction\n\
\n\
General flags:\n\
  -i <fastq|fasta|csv|tsv> - force input file type; for merge operation forces ALL input file types\n\
  -o <fastq|fasta|csv|tsv> - force output file type\n\
  -v - verbose output\n\
\n\
Format-specific flags:\n\
  -splitfasta - for fasta output split data by 80 characters in a row\n\
  -omitquality - for csv/tsv files omit Quality column\n\
  -columns <NDSQ.> - for csv/tsv files specify order of Name, Desc, Seq, Quality columns; use in any order\n\
  -nocolumndefs - for csv/tsv input ignore column definitions if any, duplicates -columns NDSQ\n\
  -defquality <quality> - for fastq output specifies default quality symbol (! is default)\n\
  -duplicatefastqids - for fastq output duplicate id and description after + symbol\n\
\n\
Examples:\n\
  geneutils c -i fastq -o fasta in.1 out.1 - converts fastq file in.1 to fasta file out.1\n\
  geneutils c -o csv -omitquality 1.fastq.gz - converts compressed fastq file 1.fastq.gz into csv format, skipping quality column\n\
  geneutils c -columns N.S..D in.tsv out.fasta - converts in.tsv in0to out.fasta; Name column is 1st, Sequence is 3rd and Description is 6th\n\
  geneutils m -v -q N 1.tsvc 2.fasta 3.fastq - merges 1.tsvc and 2.fasta into 3.fastq, using quality symbol N; verbose output\n\
  geneutils s -f 5 -o fastq 1.fasta - splits 1.fasta into 5 fastq output files\n\
  geneutils s -r 10000 1.fasta 2.fastq - splits 1.fasta into some number of fastq files, no more than 10000 records per file\n\
  geneutils s -sk 1024 1.fasta 2.fastq - splits 1.fasta into some number of fastq files, no more than 1 megabyte per file\n\
  geneutils e ref.fasta out.csv AANAT AFF1 - extract all records containing AANAT or AFF1 from ref.fasta to out.csv\n\
  geneutils e -s ref.fasta out.tsv @query.txt TCCCCGA - extract all records containing subsequences in the query.txt and TCCCCGA in DATA from ref.fasta to out.tsv\n\
  geneutils e -d ref.fastq out.fastq TCCCCGA AAGCCTT - extract all records with IDs containing TCCCCGA or AAGCCTT from ref.fastq into out_TCCCCGA.fastq and out_AAGCCTT.fastq accordingly\n\
  geneutils e -d -solexa-fastq-cutoff 30 ref.fastq out.fastq TCCCCGA AAGCCTT - extract all records with sequences containing TCCCCGA or AAGCCTT from ref.fastq into out_TCCCCGA_N30.fastq and out_AAGCCTT_N30.fastq accordingly\n\
  geneutils f -c 10 -m 2 ref.csv out.csv ATATAT – create a tabular file containing the ID, Reference sequence, query, start, end and the surrounding sequence for each of the records that contain a given query with no greater than 2 characters being different\n\
\n");
    
    exit (1);
}

int main(int argc, const char * argv[])
{
    if (argc < 3)
        help();
    
    int inputIndex = 2;
    int inputIndexCopy = inputIndex;
    auto flags = std::make_shared<CommandLineFlags>(argv, argc, &inputIndex);
    
    if (inputIndex >= argc)
        help();
    
    std::string operation = argv[1];
    std::for_each(operation.begin(), operation.end(), [](char& c){ c = std::tolower(c); });
    
    if (operation == "c" || operation == "convert")
    {
        std::vector<std::string> keys;
        std::vector<std::string> inputPaths = {argv[inputIndex]};
        BOOL isDirectory;
        NSFileManager* fileManager = [NSFileManager defaultManager];
        NSString* inputPath = [NSString stringWithUTF8String:inputPaths[0].c_str()];
        [fileManager fileExistsAtPath:inputPath isDirectory:&isDirectory];
        
        if (isDirectory)
        {
            NSArray<NSString*>* folderContents = [fileManager contentsOfDirectoryAtPath:inputPath
                                                                                  error:nil];
            for (NSString* fileName in folderContents)
            {
                std::string path = [inputPath stringByAppendingPathComponent:fileName].UTF8String;
                inputPaths.push_back(path);
            }
        }
        auto cvt = std::make_unique<Converter>(inputPaths, (inputIndex < argc) ? std::string(argv[inputIndex+1]) : "", flags);
        
        if (!cvt)
            return 2;
        
        return cvt->process();
    }
    else if (operation == "m" || operation == "merge")
    {
        if (inputIndex+1 >= argc)
            help();
        
        std::vector<std::string> inputs;
        for (;inputIndex + 1 < argc; inputIndex++)
            inputs.push_back(argv[inputIndex]);
        
        auto mgr = std::make_unique<Merger>(inputs, std::string(argv[inputIndex]), flags);
        
        if (!mgr)
            return 2;
        
        return mgr->process();
    }
    else if (operation == "s" || operation == "split")
    {
        auto spl = std::make_unique<Splitter>(argv[inputIndex], (inputIndex < argc) ? argv[inputIndex+1] : "", flags);
        
        if (!spl)
            return  2;
        return spl->process();
    }
    else if (operation == "e" || operation == "extract")
    {
        if (inputIndex+2 >= argc)
            help();
        
        std::vector<std::string> keys;
        for (int i = inputIndex+2; i < argc; i++)
            keys.push_back(argv[i]);
        
        auto ext = std::make_unique<Extractor>(argv[inputIndex], argv[inputIndex+1], flags, keys);
        if (!ext)
            return 2;
        return ext->process();
    }
    else if (operation == "u" || operation == "mutate")
    {
        if (inputIndex+2 >= argc)
            help();
        
        CommandLineFlagsObj *flags = [CommandLineFlagsObj flagsWithArguments:argv
                                                                      number:argc
                                                                  atPosition:&inputIndexCopy];
        Mutator *mut = [[Mutator alloc] initWithInput:argv[inputIndexCopy+2] reference:argv[inputIndexCopy] transReference:argv[inputIndexCopy+1] flags:flags];
        if (!mut)
            return 2;
        return [mut process]?0:3;
    }
    else if (operation == "f" || operation == "find")
    {
        if (inputIndex+2 >= argc)
            help();
        
        std::vector<std::string> keys;
        std::vector<std::string> inputPaths = {argv[inputIndex]};
        for (int i = inputIndex + 2; i < argc; i++)
            keys.push_back(argv[i]);
        
        BOOL isDirectory;
        NSFileManager* fileManager = [NSFileManager defaultManager];
        NSString* inputPath = [NSString stringWithUTF8String:inputPaths[0].c_str()];
        [fileManager fileExistsAtPath:inputPath isDirectory:&isDirectory];
        
        if (isDirectory)
        {
            NSArray<NSString*>* folderContents = [fileManager contentsOfDirectoryAtPath:inputPath
                                                                                  error:nil];
            for (NSString* fileName in folderContents)
            {
                std::string path = [inputPath stringByAppendingPathComponent:fileName].UTF8String;
                inputPaths.push_back(path);
            }
        }
        
        auto finder = std::make_unique<Finder>(inputPaths, argv[inputIndex + 1], flags, keys);
        
        if (!finder)
            return 2;
        
        return finder->process();
    }
    help();
    return 0;
}

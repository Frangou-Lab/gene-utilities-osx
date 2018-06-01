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

#import "Utils.h"
#import "SequenceFileObj.h"

@implementation Utils

static NSCharacterSet *nucleotides = nil;

+(NSString *)constructOutputNameWithFile:(SequenceFileObj *)inputFile output: (const char *)output flags: (CommandLineFlagsObj *)flags withSuffix: (NSString *)suffix
{
    if (output)
    {
        if ([suffix isEqualToString:@"-split"])
        {
            NSString *outputFilePath = [NSString stringWithUTF8String:output];
            NSString *pathExtension = outputFilePath.pathExtension;
            return [[[outputFilePath stringByDeletingPathExtension] stringByAppendingString:suffix] stringByAppendingPathExtension:pathExtension];
        }
        else
        {
            return [NSString stringWithUTF8String:output];
        }
    }
    enum FileType type = [inputFile fileType];
    // Have to construct output, check out file type flag
    if ([flags outputFormat] != Unknown)
        type = [flags outputFormat];
    
    return [[[inputFile.fileName stringByDeletingPathExtension] stringByAppendingString:suffix] stringByAppendingPathExtension:[SequenceFileObj type2extension:type]];
}

+ (NSString *)constructOutputPathWithInput:(NSString *)inputPath output: (const char *)output flags: (CommandLineFlagsObj*)flags withSuffix: (NSString *)suffix
{
    if (output)
    {
        if ([suffix isEqualToString:@"-split"])
        {
            NSString *outputFilePath = [NSString stringWithUTF8String:output];
            NSString *pathExtension = outputFilePath.pathExtension;
            return [[[outputFilePath stringByDeletingPathExtension] stringByAppendingString:suffix] stringByAppendingPathExtension:pathExtension];
        }
        else
        {
            return [NSString stringWithUTF8String:output];
        }
    }
    enum FileType type = [SequenceFileObj str2type:inputPath.pathExtension];
    // Have to construct output, check out file type flag
    if ([flags outputFormat] != Unknown)
        type = [flags outputFormat];
    
    return [[[inputPath.lastPathComponent stringByDeletingPathExtension] stringByAppendingString:suffix] stringByAppendingPathExtension:[SequenceFileObj type2extension:type]];
}

+(NSString *)insertSuffix: (NSString *)suffix toFile:(NSString *)file
{
    return [[[file stringByDeletingPathExtension] stringByAppendingString:suffix] stringByAppendingPathExtension:[file pathExtension]];
}

+(NSCharacterSet *)nucleotides
{
    if (!nucleotides)
        nucleotides = [NSCharacterSet characterSetWithCharactersInString:@"TCGA"];
    return nucleotides;
}


@end

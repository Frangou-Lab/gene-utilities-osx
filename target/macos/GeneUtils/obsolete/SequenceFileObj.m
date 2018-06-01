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

#import "SequenceFileObj.h"
#import "FastaFileObj.h"
#import "FastqFileObj.h"
#import "GenomicCsvFileObj.h"
#import "GenomicTsvFileObj.h"
#import "StringInputStreamObj.h"
#import "StringOutputStreamObj.h"
#import <assert.h>

@implementation SequenceFileObj

@synthesize fileType = _fileType;
@synthesize fileName = _fileName;

+(NSSet<NSString *> *)extensions
{
    assert(false);
    return nil;
}

+(NSString *)defaultExtension
{
    assert(false);
    return nil;
}

+ (NSArray<NSString *> *)supportedFileFormats
{
    return [[[[[NSArray new] arrayByAddingObjectsFromArray:FastaFileObj.extensions.allObjects]
                     arrayByAddingObjectsFromArray:FastqFileObj.extensions.allObjects]
                    arrayByAddingObjectsFromArray:GenomicCsvFileObj.extensions.allObjects]
                   arrayByAddingObjectsFromArray:GenomicTsvFileObj.extensions.allObjects];
}

+ (NSArray<NSString *> *)defaultFileFormats
{
    return @[FastaFileObj.defaultExtension, FastqFileObj.defaultExtension,
             GenomicCsvFileObj.defaultExtension, GenomicTsvFileObj.defaultExtension];
}

+(enum FileType)str2type: (NSString *)str
{
    if (!str)
        return Unknown;
    if ([str isEqualToString:@"fasta"])
        return Fasta;
    if ([str isEqualToString:@"fastq"])
        return Fastq;
    if ([str isEqualToString:@"csv"])
        return Csv;
    if ([str isEqualToString:@"tsv"])
        return Tsv;
    return Unknown;
}

+(NSString *)type2str: (enum FileType)type
{
    switch (type)
    {
        case Fasta:
            return @"fasta";
        case Fastq:
            return @"fastq";
        case Csv:
            return @"csv";
        case Tsv:
            return @"tsv";
        default:
            return nil;
    }
}

+(NSString *)type2extension: (enum FileType)type
{
    switch (type)
    {
        case Fasta:
            return [FastaFileObj defaultExtension];
        case Fastq:
            return [FastqFileObj defaultExtension];
        case Csv:
            return [GenomicCsvFileObj defaultExtension];
        case Tsv:
            return [GenomicTsvFileObj defaultExtension];
        default:
            return nil;
    }
}
+(enum FileType)extension2type: (NSString *)ext
{
    if ([[FastaFileObj extensions] containsObject:ext])
        return Fasta;
    if ([[FastqFileObj extensions] containsObject:ext])
        return Fastq;
    if ([[GenomicCsvFileObj extensions] containsObject:ext])
        return Csv;
    if ([[GenomicTsvFileObj extensions] containsObject:ext])
        return Tsv;
    
    return Unknown;
}

+(NSString *)str2extension:(NSString *)str
{
    return [self type2extension:[self str2type:str]];
}

+(NSString *)extension2str:(NSString *)ext
{
    return [self type2str:[self extension2type:ext]];
}

+(SequenceFileObj *)fileWithName: (NSString *)name flags: (CommandLineFlagsObj *)flags isRead: (BOOL)read
{
    enum FileType type = read ? [flags inputFormat]:[flags outputFormat];
    if (type == Unknown) // Determine from name
    {
        type = [SequenceFileObj extension2type:[name pathExtension]];
        if (type == Unknown)
        {
            type = [SequenceFileObj extension2type:[[name stringByDeletingPathExtension] pathExtension]]; // For example: 'fastq.gz'
        }
    }
    
    switch (type)
    {
        case Fasta:
            return [[FastaFileObj alloc] initWithPath:name flags:flags isRead:read];
        case Fastq:
            return [[FastqFileObj alloc] initWithPath:name flags:flags isRead:read];
        case Csv:
            return [[GenomicCsvFileObj alloc] initWithPath:name flags:flags isRead:read];
        case Tsv:
            return [[GenomicTsvFileObj alloc] initWithPath:name flags:flags isRead:read];
        default:
            return nil;
    }
}

-(NSString *)strFileType
{
    return [SequenceFileObj type2str:_fileType];
}


-(id)initWithPath: (NSString *)path type:(enum FileType) type flags: (CommandLineFlagsObj*)flags isRead: (BOOL)read
{
    if (!(self = [super init]))
        return nil;
    
    _fileType = type;
    _fileName = path;
    _flags =  flags;
    
    if (read)
        _inFile = [[StringInputStreamObj alloc] initWithFileName:path.UTF8String];
    else
        _outFile = [[StringOutputStreamObj alloc] initWithFileName:path.UTF8String];
    
    if (!_inFile && !_outFile)
        return nil;
    return self;
}

- (void)dealloc
{
    _inFile = nil;
    _outFile = nil;
}

-(BOOL)isValidGeneFile
{
    return YES;
}

-(GeneSequenceObj *)read
{
    assert(false);
    return nil;
}

- (void)write:(GeneSequenceObj *)seq
{
    assert(false);
}



@end

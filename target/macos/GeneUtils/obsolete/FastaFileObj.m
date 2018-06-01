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

#import "FastaFileObj.h"
#import "CommandLineFlagsObj.h"
#import "StringInputStreamObj.h"
#import "StringOutputStreamObj.h"
#import "GeneSequenceObj.h"

#include <libgene/log/Logger.hpp>

static NSSet<NSString *> *fastaExts = nil;

@implementation FastaFileObj

+(NSSet<NSString *> *)extensions
{
    if (!fastaExts)
        fastaExts = [NSSet setWithObjects:@"fas", @"fasta", @"fna", @"ffn", @"faa", @"frn", nil];
    return fastaExts;
}
+(NSString *)defaultExtension
{
    return @"fasta";
}

-(id)initWithPath: (NSString *)path flags: (CommandLineFlagsObj *)flags isRead: (BOOL)read;
{
    if ((self = [super initWithPath:path type:Fasta flags: flags isRead:read]))
    {
        _split = [_flags checkSetting:@"splitfasta"];
        if (_flags.verbose && _split)
            PrintfLog("Limiting sequence length to 80 characters\n");
    }
    return self;
}

-(GeneSequenceObj *)read
{
    @autoreleasepool {
        if (!_lastReadString)
        {
            while ((_lastReadString = [[_inFile readLine] copy]))
                if ([_lastReadString characterAtIndex:0] != '>')
                    _lastReadString = nil;
                else
                    break;
        }
        if (!_lastReadString || _lastReadString.length == 0)
            return nil;
        NSRange space = [_lastReadString rangeOfString:@" "];
        NSString *desc = @"";
        NSString *name;
        if (space.location == NSNotFound) // No desc
        {
            name = [_lastReadString substringFromIndex:1];
        }
        else
        {
            name = [_lastReadString substringWithRange:NSMakeRange(1, space.location-1)];
            desc = [_lastReadString substringFromIndex:space.location + 1];
        }
        NSMutableString *data = [[NSMutableString alloc] init];
        // Data....
        while ((_lastReadString = [_inFile readLine]))
        {
            if (_lastReadString.length == 0 || [_lastReadString characterAtIndex:0] == '>') // Found next sequence beginning
                break;
            [data appendString:_lastReadString];
        }
        return [[GeneSequenceObj alloc] initWithName:name desription:desc sequence:data];
    }
}

-(void)write: (GeneSequenceObj *)seq
{
    @autoreleasepool {
        [_outFile writeChar:'>'];
        if (seq.desc.length == 0)
        {
            [_outFile writeString:seq.name];
        }
        else
        {
            [_outFile write:seq.name];
            [_outFile writeChar:' '];
            [_outFile writeString:seq.desc];
        }
        
        if (_split)
            // Data, split by 80 chars max
            for (int i = 0; i < seq.seq.length; i += 80)
            {
                NSRange r = NSMakeRange(i, MIN(seq.seq.length - i, 80));
                [_outFile writeString:[seq.seq substringWithRange:r]];
            }
        else
        {
            [_outFile writeString:seq.seq];
        }
    }
    
}

@end

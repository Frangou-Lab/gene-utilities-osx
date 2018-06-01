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

#import "FastqFileObj.h"
#import "CommandLineFlagsObj.h"
#import "StringInputStreamObj.h"
#import "StringOutputStreamObj.h"
#import "GeneSequenceObj.h"

static NSSet<NSString *> *fastqExts = nil;

@implementation FastqFileObj

+(NSSet<NSString *> *)extensions
{
    if (!fastqExts)
        fastqExts = [NSSet setWithObjects:@"fq", @"fastq", nil];
    return fastqExts;
}
+(NSString *)defaultExtension
{
    return @"fastq";
}

-(id)initWithPath: (NSString *)path flags: (CommandLineFlagsObj *)flags isRead: (BOOL)read;
{
    if ((self = [super initWithPath: path type:Fastq flags: flags isRead:read]))
    {
        _defQuality = [_flags quality];
        _duplicate = [flags checkSetting:@"duplicatefastqids"];
    }
    return self;
}

-(GeneSequenceObj *)read
{
    @autoreleasepool {
        NSString *lastReadString;
        while ((lastReadString = [_inFile readLine]))
            if ([lastReadString characterAtIndex:0] != '@')
                lastReadString = nil;
            else
                break;
        if (!lastReadString)
            return nil;
        NSRange space = [lastReadString rangeOfString:@" "];
        NSString *desc = @"";
        NSString *name;
        if (space.location == NSNotFound) // No desc
        {
            name = [lastReadString substringFromIndex:1];
        }
        else
        {
            name = [lastReadString substringWithRange:NSMakeRange(1, space.location-1)];
            desc = [lastReadString substringFromIndex:space.location + 1];
        }
        NSString *data = [_inFile readLine];
        // Skip until '+' string
        while ((lastReadString = [_inFile readLine]))
        {
            if ([lastReadString characterAtIndex:0] != '+')
                lastReadString = nil;
            else
                break;
        }
        NSString *quality = [_inFile readLine];
        return [[GeneSequenceObj alloc] initWithName:name desription:desc sequence:data quality:quality];
    }
}

-(void)write: (GeneSequenceObj *)seq
{
    @autoreleasepool {
        [_outFile writeChar:'@'];
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
        [_outFile writeString:seq.seq];
        
        if (_duplicate)
        {
            [_outFile writeChar:'+'];
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
        }
        else
        {
            [_outFile writeString:@"+"];
        }
        
        if (seq.quality.length > 0)
        {
            [_outFile writeString:seq.quality];
        }
        else
        {
            // Write long string from default quality
            // TODO: optimize?
            NSString *padString = [NSString stringWithFormat:@"%c", _defQuality];
            [_outFile writeString:[@"" stringByPaddingToLength:seq.seq.length withString:padString startingAtIndex:0]];
            
           // for (int i = 0; i < seq.seq.length; i ++)
           //     [_outFile writeChar:_defQuality];
        }
    }
}


@end

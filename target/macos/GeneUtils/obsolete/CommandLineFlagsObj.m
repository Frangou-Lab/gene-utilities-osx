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
#import "SequenceFileObj.h"

static const char * flagsWithParameters[] = {"i", "o", "defquality", "f", "r", "sk",
    "sm", "columns", "c", "m"};

@implementation CommandLineFlagsObj

- (instancetype)init
{
    if (!(self = [super init]))
        return nil;
    
    dict = [NSMutableDictionary new];
    _verbose = NO;
    return self;
}

-(id)initWithArguments: (const char **)argv number: (int)argc atPosition: (int *)pStart
{
    if (!(self = [self init]))
        return nil;
    
    while (*pStart < argc)
    {
        if (argv[*pStart][0] != '-')
            break;
        NSString *flag = [NSString stringWithUTF8String:argv[*pStart]+1];
        
        ++*pStart;
        if ([flag length] == 0)
            continue;
        // Check if have parameters
        bool params = NO;
        for (int i = 0; flagsWithParameters[i]; i++)
            if (!strcmp(flagsWithParameters[i], [flag UTF8String]))
            {
                params = YES;
                break;
            }
        NSString *param = @"";
        if (params && *pStart < argc)
        {
            param = [NSString stringWithUTF8String:argv[*pStart]];
            ++*pStart;
        }
        [dict setObject:param forKey:flag];
        
        _verbose = [self checkSetting:@"v"];
    }
    return self;
}

+(id)flagsWithArguments: (const char **)argv number: (int)argc atPosition: (int *)pStart
{
    return [[CommandLineFlagsObj alloc] initWithArguments:argv number:argc atPosition:pStart];
}

-(enum FileType)inputFormat
{
    return [SequenceFileObj str2type:[dict objectForKey:@"i"]];
}
-(enum FileType)outputFormat
{
    return [SequenceFileObj str2type:[dict objectForKey:@"o"]];
}

-(char)quality
{
    NSString *q = [dict objectForKey:@"defquality"];
    if (!q)
        return 'I';
    return [q characterAtIndex:0];
}

-(BOOL)checkSetting: (NSString *)name
{
    return [dict objectForKey:name] != nil;
}

-(int)getIntSetting: (NSString *)name
{
    NSString *val = [dict objectForKey:name];
    if (!val)
        return 0;
    return [val intValue];
}

-(NSString *)getSetting: (NSString *)name // Returns nil if no setting exists
{
    return [dict objectForKey:name];
}

- (void)setSetting:(NSString *)value withKey:(NSString *)key
{
    [dict setObject:value forKey:key];
}

@end

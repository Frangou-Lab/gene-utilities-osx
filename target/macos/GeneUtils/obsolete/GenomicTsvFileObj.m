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

#import "GenomicTsvFileObj.h"
#include <libgene/def/FileType.hpp>

static NSSet<NSString *> *tsvExts = nil;

@implementation GenomicTsvFileObj

+ (NSSet<NSString *> *)extensions
{
    if (!tsvExts)
        tsvExts = [NSSet setWithObjects:@"tsv", @"tsvc", @"tsvr", @"tsvcr", nil];
    return tsvExts;
}

+ (NSString *)defaultExtension
{
    return @"tsvc";
}

- (id)initWithPath:(NSString *)path flags:(CommandLineFlagsObj *)flags isRead:(BOOL)read
{
    if ((self = [super initWithPath:path type:Tsv flags:flags isRead:read separator:'\t']))
    {
    }
    return self;
}

@end

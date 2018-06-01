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

#import "InOutFile.h"
#import "StringInputStreamObj.h"
#import "StringOutputStreamObj.h"
#import "CommandLineFlagsObj.h"

@implementation InOutFile

@synthesize fileName = _fileName;


- (NSString *)fileName
{
    if (_outFile)
        return _outFile.name;
    else
        return _inFile.name;
}

- (id)initWithPath:(NSString *)path type:(enum FileType)type flags:(CommandLineFlagsObj*)flags isRead:(BOOL)read
{
    if (!(self = [super init]))
        return nil;
 
    _flags = flags;
    _fileName = path;
    _fileType = type;
    
    if (read)
    {
        _inFile = [[StringInputStreamObj alloc] initWithFileName:path.UTF8String];
    }
    else
    {
        _outFile = [[StringOutputStreamObj alloc] initWithFileName:path.UTF8String];
    }
    return self;
}

+ (instancetype)fileWithName:(NSString *)name flags:(CommandLineFlagsObj*)flags isRead:(BOOL)read
{
    return [[InOutFile alloc] initWithPath:name type:Csv flags:flags isRead:read];
}

- (long)length
{
    if (_inFile)
        return [_inFile length];
    if (_outFile)
        return [_outFile length];
    return -1l;
}

-(long)getPos
{
    if (_inFile)
        return [_inFile getPos];
    if (_outFile)
        return [_outFile getPos];
    return -1l;
}


@end

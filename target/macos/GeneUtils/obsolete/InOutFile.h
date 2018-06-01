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

@class CommandLineFlagsObj;
@class StringInputStreamObj;
@class StringOutputStreamObj;

#if __cplusplus

#define CXX_WAS_DEFINED
#undef __cplusplus

#endif

#include <libgene/def/FileType.hpp>

@interface InOutFile : NSObject
{
    StringInputStreamObj *_inFile;
    StringOutputStreamObj *_outFile;
    CommandLineFlagsObj *_flags;
}

@property (copy, readonly) NSString *fileName;
@property (readonly) enum FileType fileType;


+ (instancetype)fileWithName:(NSString *)name flags:(CommandLineFlagsObj *)flags isRead:(BOOL)read;

- (id)initWithPath:(NSString *)path type:(enum FileType)type flags:(CommandLineFlagsObj *)flags isRead:(BOOL)read;

- (long)length;
- (long)getPos;

@end

#ifdef CXX_WAS_DEFINED
#define __cplusplus
#endif

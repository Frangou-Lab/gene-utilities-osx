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
#import "InOutFile.h"
#import "ColumnTypesConfiguration.h"

@class Lexer;

@interface SeparatedFileObj : InOutFile
{
    BOOL _headerDone;
}

@property (readonly) BOOL headerPresent;
@property (nonatomic, readonly) NSMutableArray<NSString *> *header;
@property (copy, readonly) NSString *lastReadString;
@property (readonly) Lexer *lexer;
@property (readwrite) ColumnTypesConfiguration *columnTypes;
@property (readonly) char separator;

-(id)initWithPath:(NSString *)path flags:(CommandLineFlagsObj*)flags isRead:(BOOL)read separator:(char)separator;
-(NSArray<NSString *> *)readNextRow;

// Needs refactoring
- (void)setUpWithReadMode:(BOOL)read;
- (void)readHeader;
- (void)addColumn:(int)columnId withType:(enum ColumnType)type withDescription:(NSString*)description;
- (void)saveConfigurationOfColumnTypesForFile:(NSString *)inputFile;
- (void)addColumnToHeader:(NSString *)columnName;
- (void)writeHeaderIntoFile;
- (void)write:(NSString *)str;
- (void)writeChar:(char)ch;

@end

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

#import "SeparatedFileObj.h"
#import "CommandLineFlagsObj.h"
#import "StringInputStreamObj.h"
#import "StringOutputStreamObj.h"
#import "Lexer.h"

@interface SeparatedFileObj(Private)

-(void)parseColumnsInfo;
-(void)prepare: (BOOL)read;

@end


@implementation SeparatedFileObj

@synthesize header = _header;
@synthesize fileName = _fileName;

// TODO: header precence through flags
-(id)initWithPath:(NSString *)path flags:(CommandLineFlagsObj*)flags isRead:(BOOL)read separator:(char)separator
{
    if ((self = [super initWithPath:path type:(separator == ',' ? Csv : Tsv)
                              flags:flags isRead:read]))
    {
        _separator = separator;
        _headerPresent = YES;
        _headerDone = NO;
        _lexer = [[Lexer alloc] initWithOperators:[NSArray arrayWithObjects:[NSString stringWithFormat:@"%c", _separator], nil]];
        
        [self prepare:read];
    }
    return self;
}

-(void)prepare: (BOOL)read
{
    if (_headerDone)
        return;
    
    _header = [NSMutableArray array];
    _headerDone = YES;
    
    _columnTypes = [ColumnTypesConfiguration configuration];
    if (read)
        [_columnTypes readConfigurationOfColumnTypesForFile:[self fileName]];
    
    [self parseColumnsInfo];
    
    if (!read) // Add and write columns info
    {
        [_columnTypes saveConfigurationOfColumnTypesForFile:[self fileName]];
        _header = [NSMutableArray new];
        
        if (!_headerPresent)
            return;
    }
    else
    {
        if (!_headerPresent)
            return;
        
        NSString *header = [_inFile readLine];
        [_lexer setExpression:header];
        while ([_lexer next])
            if (Literal == [_lexer type])
                [_header addObject:[_lexer lexeme]];
    }
}

- (void)readHeader
{
    if (!_headerPresent)
        return;
    
    NSString *header = [_inFile readLine];
    [_lexer setExpression:header];
    while ([_lexer next])
        if (Literal == [_lexer type])
            [_header addObject:[_lexer lexeme]];
}

- (void)setUpWithReadMode:(BOOL)read
{
    if (_headerDone)
        return;
    
    _header = [NSMutableArray array];
    _headerDone = YES;
    
    _columnTypes = [ColumnTypesConfiguration configuration];
    if (read)
        [_columnTypes readConfigurationOfColumnTypesForFile:[self fileName]];
}

- (void)parseColumnsInfo
{
    
}

- (void)addColumn:(int)columnId withType:(enum ColumnType)type withDescription:(NSString*)description
{
    [_columnTypes addColumn:columnId withType:type withDescription:description];
}

- (void)saveConfigurationOfColumnTypesForFile:(NSString *)inputFile
{
    [_columnTypes saveConfigurationOfColumnTypesForFile:inputFile];
}

- (void)addColumnToHeader:(NSString *)columnName
{
    [_header addObject:[columnName copy]];
}

- (void)writeHeaderIntoFile
{
    [_outFile write:[_header objectAtIndex:0]];
    for (int i = 1; i < [_header count]; i++)
    {
        [_outFile writeChar:_separator];
        [_outFile write:[_header objectAtIndex:i]];
    }
    [_outFile write:@"\n"];
}

- (void)write:(NSString *)str
{
    [_outFile write:str];
}

- (void)writeChar:(char)ch
{
    [_outFile writeChar:ch];
}

- (char)getSeparator
{
    return _separator;
}

-(NSArray<NSString *> *)readNextRow
{
    @autoreleasepool {
        _lastReadString = [_inFile readLine];
        if (!_lastReadString)
            return nil;
    
        NSMutableArray<NSString *> *row = [NSMutableArray arrayWithCapacity:[_header count]];
        [_lexer setExpression:_lastReadString];
        while ([_lexer next])
            if (Literal == [_lexer type])
                [row addObject:[_lexer lexeme]];
        return row;
    }
}

@end

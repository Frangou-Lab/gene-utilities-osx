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

#import "GenomicSeparatedFileObj.h"
#import "ColumnTypesConfiguration.h"
#import "StringInputStreamObj.h"
#import "StringOutputStreamObj.h"
#import "GeneSequenceObj.h"

#include <libgene/log/Logger.hpp>

@interface GenomicSeparatedFileObj(Private)

-(void)parseColumnsInfo;
-(void)prepare: (BOOL)read;

@end

@implementation GenomicSeparatedFileObj
{
    NSCharacterSet *_delimCharSet;
    
}

-(id)initWithPath: (NSString *)path type:(enum FileType) type flags: (CommandLineFlagsObj*)flags isRead: (BOOL)read separator: (char)separator
{
    if ((self = [super init]))
    {
        _file = [[SeparatedFileObj alloc] initWithPath:path flags:_flags isRead:read separator:separator];
        
        if (read)
            _inFile = [[StringInputStreamObj alloc] initWithFileName:path.UTF8String];
        else
            _outFile = [[StringOutputStreamObj alloc] initWithFileName:path.UTF8String];
        
        _delimCharSet = [NSCharacterSet characterSetWithCharactersInString:[NSString stringWithFormat:@"%c", _file.separator]];
        [self prepare:read];
    }
    return self;
}

- (void)prepare:(BOOL)read
{
    [_file setUpWithReadMode:read];
    [self parseColumnsInfo];
    
    if (!read) // Add and write columns info
    {
        if (_nameCol != NSNotFound)
            [_file addColumn:(int)_nameCol withType:ID withDescription:@"Name"];
        if (_descCol != NSNotFound)
            [_file addColumn:(int)_descCol withType:Desc withDescription:@"Description"];
        if (_seqCol != NSNotFound)
            [_file addColumn:(int)_seqCol withType:Data withDescription:@"Sequence"];
        if (_qualityCol != NSNotFound)
            [_file addColumn:(int)_qualityCol withType:Data withDescription:@"Quality"];
        
        [_file saveConfigurationOfColumnTypesForFile:[self fileName]];
    }
    
    
    if (read)
    {
        [_file readHeader];
    }
    else
    {
        // Form header
        int64_t cNum = MAX(MAX(MAX(_nameCol, _descCol), _seqCol), _qualityCol)+1;
        if (cNum <= 0)
            return;
        
        for (int i = 0; i < cNum; i++)
        {
            if (i == _nameCol)
                [_file addColumnToHeader:@"Name"];
            else if (i == _descCol)
                [_file addColumnToHeader:@"Description"];
            else if (i == _seqCol)
                [_file addColumnToHeader:@"Sequence"];
            else if (i == _qualityCol)
                [_file addColumnToHeader:@"Quality"];
            else
                [_file addColumnToHeader:@"Unknown"];
        }
        
        if (!_file.headerPresent)
            return;
        
        [_file writeHeaderIntoFile];
    }
}

- (NSMutableArray<NSString *> *)getHeader
{
    return _file.header;
}

-(void)parseColumnsInfo
{
    NSString *defString = nil;
    
    _nameCol = 0;
    _descCol = 1;
    _seqCol = 2;
    _qualityCol = 3;
 
    // Now columns
    if ([_flags checkSetting: @"nocolumndefs"])
    {
        if (_flags.verbose)
            PrintfLog("Using defalut columns order NDSQ\n");
    } else if ((defString = [[_flags getSetting:@"columns"] uppercaseString])) // From string...
    {
        if (_flags.verbose)
            PrintfLog("Parsing columns order from flag...\n");
        _nameCol = _descCol = _seqCol = _qualityCol = -1;
        NSUInteger ui;
        ui = [defString rangeOfString:@"N"].location;
        if (ui != NSNotFound)
            _nameCol = (int)ui;
        ui = [defString rangeOfString:@"D"].location;
        if (ui != NSNotFound)
            _descCol = (int)ui;
        ui = [defString rangeOfString:@"S"].location;
        if (ui != NSNotFound)
            _seqCol = (int)ui;
        ui = [defString rangeOfString:@"Q"].location;
        if (ui != NSNotFound)
            _qualityCol = (int)ui;
    }
    else if (_file.columnTypes.columns.count > 0)// From column types
    {
        if (_flags.verbose)
            PrintfLog("Parsing columns order from columns definition...\n");
        _nameCol = _descCol = _seqCol = _qualityCol = -1;
        if ([_file.columnTypes IDColumn])
            _nameCol = [_file.columnTypes IDColumn].columnId;
        NSArray *descs = [_file.columnTypes columnsWithType:Desc];
        if ([descs count] > 0)
            _descCol = [[descs objectAtIndex:0] columnId];
        NSArray *data = [_file.columnTypes columnsWithType:Data];
        if ([data count] > 0)
            _seqCol = [[data objectAtIndex:0] columnId];
        if ([data count] > 1)
            _qualityCol = [[data objectAtIndex:1] columnId];
    }
    
    if([_flags checkSetting:@"omitquality"])
    {
        _qualityCol = -1;
        if (_flags.verbose)
            PrintfLog("Skipping quality column\n");
    }
    
    if (_flags.verbose)
    {
        if (_nameCol >= 0)
            PrintfLog("Name column: %lld\n", _nameCol);
        if (_descCol >= 0)
            PrintfLog("Description column: %lld\n", _descCol);
        if (_seqCol >= 0)
            PrintfLog("Sequence column: %lld\n", _seqCol);
        if (_qualityCol >= 0)
            PrintfLog("Quality column: %lld\n", _qualityCol);
    }
}

-(BOOL)validGeneFile
{
    return _nameCol != NSNotFound && _seqCol != NSNotFound;
}

-(GeneSequenceObj *)read
{
    @autoreleasepool {
        NSString *str = [_inFile readLine];
        if (!str)
            return nil;
        
        GeneSequenceObj *record = [[GeneSequenceObj alloc] init];
        int index = 0;
        [_file.lexer setExpression:str];
        while ([_file.lexer next])
        {
            if (Literal == [_file.lexer type])
            {
                if (index == _nameCol)
                    record.name = [_file.lexer lexeme];
                else if (index == _descCol)
                    record.desc = [_file.lexer lexeme];
                else if (index == _seqCol)
                    record.seq = [_file.lexer lexeme];
                else if (index == _qualityCol)
                    record.quality = [_file.lexer lexeme];
            }
            else if (Operator == [_file.lexer type])
                ++index;
        }
        return record;
    }
}

// TODO: columnd defs through flags
-(void)write: (GeneSequenceObj *)seq
{
    @autoreleasepool {
        BOOL standardOrder = (_nameCol == 0) && (_descCol == 1) && (_seqCol == 2) && (_qualityCol == 3);
        if (standardOrder)
        {
            [_file write:seq.name];
            [_file writeChar:_file.separator];
            [_file write:seq.desc];
            [_file writeChar:_file.separator];
            [_file write:seq.seq];
            [_file writeChar:_file.separator];
            [_file write:seq.quality];
            [_file writeChar:_file.separator];
        }
        else
        {
            for (int i = 0; i < [_file.header count]; i++)
            {
                if (i != 0)
                    [_file writeChar:_file.separator];
                if (i == _nameCol)
                    [_file write:seq.name];
                else if (i == _descCol)
                    [_file write:seq.desc];
                else if (i == _seqCol)
                    [_file write:seq.seq];
                else if (i == _qualityCol)
                    [_file write:seq.quality];
            }
        }
        [_file writeChar:'\n'];
    }
}

@end

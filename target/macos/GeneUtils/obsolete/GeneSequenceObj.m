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

#import "GeneSequenceObj.h"
#import "Utils.h"

@implementation GeneSequenceObj

-(id)initWithName: (NSString *)name desription: (NSString *)desc sequence: (NSString *)seq
{
    return [self initWithName:name desription:desc sequence:seq quality:@""];
}

-(id)initWithName: (NSString *)name desription: (NSString *)desc sequence: (NSString *)seq quality: (NSString *)qual
{
    if (!(self = [super init]))
        return nil;
    _name = name;
    _desc = desc;
    _seq = seq;
    _quality = qual;
    
    return self;
}

-(id) replaceSequence: (NSString *)repl atPosition: (int)pos
{
    NSString *newSeq = [_seq stringByReplacingCharactersInRange:NSMakeRange(pos, [repl length]) withString:repl];
    return [[GeneSequenceObj alloc] initWithName:_name desription:_desc sequence:newSeq quality:_quality];
}

-(id) deleteSequenceAtPosition: (NSUInteger)pos withLength: (NSUInteger) len
{
    NSString *newSeq = [_seq stringByReplacingCharactersInRange:NSMakeRange(pos, len) withString:@""];
    return [[GeneSequenceObj alloc] initWithName:_name desription:_desc sequence:newSeq quality:_quality];
}

-(id) insertSequence: (NSString *)repl atPosition: (int)pos
{
    NSString *newSeq = [_seq stringByReplacingCharactersInRange:NSMakeRange(pos, 0) withString:repl];
    return [[GeneSequenceObj alloc] initWithName:_name desription:_desc sequence:newSeq quality:_quality];
}

@end


@implementation AminoAcid

-(void)defineName
{
    _name = 0;
    
    for (int i = 0; i < 3; i++)
        if (![[Utils nucleotides] characterIsMember:_seq[i]])
            return;
    
    if (_seq[0] == 'T')
    {
        if (_seq[1] == 'T')
        {
            if (_seq[2] == 'T' || _seq[2] == 'C')
                _name = 'F';
            else
                _name = 'L';
        } else if (_seq[1] == 'C')
            _name = 'S';
        else if (_seq[1] == 'A')
        {
            if (_seq[2] == 'T' || _seq[2] == 'C')
                _name = 'Y';
            else
                _name = '!'; // stop
        } else // if (_seq[1] == 'G')
        {
            if (_seq[2] == 'T' || _seq[2] == 'C')
                _name = 'C';
            else if (_seq[2] == 'A')
                _name = '!'; // stop
            else
                _name = 'W';
        }
    } else if (_seq[0] == 'C')
    {
        if (_seq[1] == 'T')
            _name = 'L';
        else if (_seq[1] == 'C')
            _name = 'P';
        else if (_seq[1]  == 'A')
        {
            if (_seq[2] == 'T' || _seq[2] == 'C')
                _name = 'H';
            else
                _name = 'Q';
        } else // if (_seq[1] == 'G')
            _name = 'R';
    } else if (_seq[0] == 'A')
    {
        if (_seq[1] == 'T')
        {
            if (_seq[2] == 'G')
                _name = 'M';
            else
                _name = 'I';
        } else if (_seq[1] == 'C')
            _name = 'T';
        else if (_seq[1] == 'A')
        {
            if (_seq[2] == 'T' || _seq[2] == 'C')
                _name = 'N';
            else
                _name = 'K';
        } else // if (_seq[1] == 'G')
        {
            if (_seq[2] == 'T' || _seq[2] == 'C')
                _name = 'S';
            else
                _name = 'R';
        }
    } else // if (_seq[0] == 'G')
    {
        if (_seq[1] == 'T')
            _name = 'V';
        else if (_seq[1] == 'C')
            _name = 'A';
        else if (_seq[1] == 'A')
        {
            if (_seq[2] == 'T' || _seq[2] == 'C')
                _name = 'D';
            else
                _name = 'E';
        }
        else
            _name = 'G';
    }
}

-(id)initWithNucleotides: (const char *)seq
{
    if (!(self = [super init]))
        return nil;
    
    memcpy(_seq, seq, 3*sizeof(char));
    _seq[3] = 0;
    
    [self defineName];
    return self;
}


-(id)initWithNucleotides: (const char *)seq mutation: (char)mutated atPosition: (int) pos
{
    if (!(self = [self initWithNucleotides:seq]))
        return nil;
    _seq[pos] = mutated;
    [self defineName];
    return self;
}


-(id)initWithNucleotide: (char) _1 _2: (char)_2 _3: (char) _3
{
    if (!(self = [super init]))
        return nil;
    
    _seq[0] = _1;
    _seq[1] = _2;
    _seq[2] = _3;
    _seq[3] = 0;
    
    [self defineName];
    return self;
}

-(id)initWithString: (NSString *)aa
{
    return [self initWithString:aa position:0];
}
-(id)initWithString: (NSString *)aa position: (int)position
{
    if ([aa length] - position < 3)
        return nil;
    
    NSString *seq = [aa substringWithRange:NSMakeRange(position, 3)];
    
    return [self initWithNucleotide:[seq characterAtIndex:0] _2:[seq characterAtIndex:1] _3:[seq characterAtIndex:2]];
}

-(NSString *)seq
{
    return [NSString stringWithUTF8String:_seq];
}

// TODO: optimize? get rid of arrays???
-(NSArray <AminoAcid *> *)mutate: (char)nucleotide to:(char) nucleotide2;
{
    NSMutableArray<AminoAcid *> *ret = [NSMutableArray arrayWithCapacity:1];
    for (int i = 0; i < 3; i++)
        if (_seq[i] == nucleotide)
            [ret addObject:[[AminoAcid alloc] initWithNucleotides:_seq mutation:nucleotide2 atPosition:i]];
    return ret;
}

-(AminoAcid *)mutate2: (NSString *)nucleotides to:(NSString *) nucleotides2
{
    char seq[3];
    
    //May be 1-2 or 2-3 mutation only
    if (_seq[0] == [nucleotides characterAtIndex:0] && _seq[1] == [nucleotides characterAtIndex:1])
    {
        seq[0] = [nucleotides2 characterAtIndex:0];
        seq[1] = [nucleotides2 characterAtIndex:1];
        seq[2] = _seq[2];
    }
    else if (_seq[1] == [nucleotides characterAtIndex:0] && _seq[2] == [nucleotides characterAtIndex:1])
    {
        seq[0] = _seq[0];
        seq[1] = [nucleotides2 characterAtIndex:0];
        seq[2] = [nucleotides2 characterAtIndex:1];
    }
    else
        return nil;
    return [[AminoAcid alloc] initWithNucleotides:seq];
}

-(AminoAcid *)mutate: (char)nucleotide to:(char) nucleotide2 atPosition: (int) pos
{
    if (_seq[pos] != nucleotide)
        return nil;
    return [[AminoAcid alloc] initWithNucleotides:_seq mutation:nucleotide2 atPosition:pos];
}

@end

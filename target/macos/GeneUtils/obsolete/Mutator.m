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

#import "Mutator.h"
#import "Utils.h"
#import "GeneSequenceObj.h"
#import "GenomicSeparatedFileObj.h"

#include <libgene/log/Logger.hpp>

@interface Mutator(Private)
-(bool) processMutation: (NSString *)geneId atPosition: (int)pPos toPosition: (int)pPos2 fromAa: (NSString *)aaFrom toAA: (NSString *)aaTo fromSeq: (NSString *)seqFrom toSeq: (NSString *)seqTo;

@end

@implementation Mutator

@synthesize delegate = _delegate;

-(id) initWithInput: (const char *)input reference: (const char *)ref transReference: (const char *)tRef flags:(CommandLineFlagsObj*)flags
{
    if (self = [self initWithInput:input reference:ref transReference:tRef outReference:nil outTransReference:nil flags:flags])
        return self;
    else
        return nil;
}

- (id)initWithInput:(const char *)input reference:(const char *)ref transReference:(const char *)tRef outReference:(NSString *)outReference outTransReference:(NSString *)outTransReference flags:(CommandLineFlagsObj*)flags
{
    if (!(self = [super init]))
        return nil;
    
    _flags = flags;
    
    SequenceFileObj *inFile = [SequenceFileObj fileWithName:[NSString stringWithUTF8String:input] flags:flags isRead:YES];
    if (!inFile)
    {
        PrintfLog("Can't open input file");
        return nil;
    }
    if ([inFile fileType] != Csv && [inFile fileType] != Tsv)
    {
        PrintfLog("Input file should be tab or comma separated");
        return nil;
    }
    _inFile = (SeparatedFileObj *)inFile;
    
    if (!(_refFile = [SequenceFileObj fileWithName:[NSString stringWithUTF8String:ref] flags:flags isRead:YES]))
    {
        PrintfLog("Can't open reference file\n");
        return nil;
    }
    if (![_refFile isValidGeneFile])
    {
        PrintfLog("Reference file has invaid format\n");
        return nil;
    }
    
    if (!(_transRefFile = [SequenceFileObj fileWithName:[NSString stringWithUTF8String:tRef] flags:flags isRead:YES]))
    {
        PrintfLog("Can't open translation reference file\n");
        return nil;
    }
    if (![_transRefFile isValidGeneFile])
    {
        PrintfLog("Translation reference file has invaid format\n");
        return nil;
    }
    if (!outReference) {
        outReference = [Utils constructOutputNameWithFile:_refFile output:nil flags:_flags withSuffix:@"-mutated"];
    }
    
    if (!(_outFile = [SequenceFileObj fileWithName:outReference flags:_flags isRead:NO]))
    {
        PrintfLog("Can't create output file\n");
        return nil;
    }
    
    if (!outTransReference) {
        outTransReference = [Utils constructOutputNameWithFile:_transRefFile output:nil flags:_flags withSuffix:@"-mutated"];
    }
    
    if (!(_transOutFile = [SequenceFileObj fileWithName:outTransReference flags:_flags isRead:NO]))
    {
        PrintfLog("Can't create output file\n");
        return nil;
    }
    
    return self;
}

-(BOOL) process
{
    GeneSequenceObj *seq;
    
    if (_flags.verbose)
        PrintfLog("Analyzing %s...\n", [[_inFile fileName] UTF8String]);
    
    NSMutableArray<NSString *> * header;
    if ([_inFile.class isSubclassOfClass:GenomicSeparatedFileObj.class])
        header = ((GenomicSeparatedFileObj *)_inFile).header;
    else
        header = _inFile.header;
    
    if ([header count] == 0)
    {
        PrintfLog("Input file is empty\n");
        return NO;
    }
    _gene = _geneSymbol = _transcript = _proteinPos = _aaChange = _alt = _ref  = -1;
    for (int i = 0; i < [header count]; i++)
    {
        NSString *name = [[header objectAtIndex:i] lowercaseString];
        if ([name isEqualToString:@"gene"])
            _gene = i;
        else if ([name isEqualToString:@"gene symbol"])
            _geneSymbol = i;
        else if ([name isEqualToString:@"transcript"])
            _transcript = i;
        else if ([name isEqualToString:@"protein_pos"])
            _proteinPos = i;
        else if ([name isEqualToString:@"aa_change"])
            _aaChange = i;
        else if ([name isEqualToString:@"alt"])
            _alt = i;
        else if ([name isEqualToString:@"ref"])
            _ref = i;
    }
    if (_gene < 0)
    {
        PrintfLog("Column Gene not found\n");
        return NO;
    }
    if (_geneSymbol < 0)
    {
        PrintfLog("Column GeneSymbol not found\n");
        return NO;
    }
    if (_transcript < 0)
    {
        PrintfLog("Column Transcript not found\n");
        return NO;
    }
    if (_proteinPos < 0)
    {
        PrintfLog("Column Protein_Pos not found\n");
        return NO;
    }
    if (_aaChange < 0)
    {
        PrintfLog("Column AA_Change not found\n");
        return NO;
    }
    if (_alt < 0)
    {
        PrintfLog("Column Alt not found\n");
        return NO;
    }
    if (_ref < 0)
    {
        PrintfLog("Column Ref not found\n");
        return NO;
    }
    
    if (_flags.verbose)
        PrintfLog("Reading reference file %s\n", [[_refFile fileName] UTF8String]);
    _reference = [NSMutableDictionary dictionary];
    while ((seq = [_refFile read]))
        [_reference setObject:seq forKey:[seq.name uppercaseString]];
    
    if (_flags.verbose)
        PrintfLog("Reading translation reference file %s\n", [[_transRefFile fileName] UTF8String]);
    _transReference = [NSMutableDictionary dictionary];
    while ((seq = [_transRefFile read]))
        [_transReference setObject:seq forKey:[seq.name uppercaseString]];

    if (_flags.verbose)
        PrintfLog("Processing...\n");
 
    NSDate *start = [NSDate date];
    long counter = 0, successCounter = 0;
    NSArray<NSString *> *row;
    
    while ((row = [_inFile readNextRow]))
    {
        ++counter;
        
        NSUInteger rowLen = [row count];
        if (_gene >= rowLen || _geneSymbol >= rowLen || _transcript >= rowLen || _proteinPos >= rowLen || _aaChange >= rowLen || _alt >= rowLen || _ref >= rowLen) // To short
        {
            PrintfLog("Warning: ignoring too short string %s\n", [_inFile.lastReadString UTF8String]);
            continue;
        }
        // id
        NSString *geneId = [NSString stringWithFormat:@"%@|%@|%@", [[row objectAtIndex:_gene] uppercaseString], [[row objectAtIndex:_transcript] uppercaseString], [[row objectAtIndex:_geneSymbol] uppercaseString]];
        // protein position
        NSString *strPos = [row objectAtIndex:_proteinPos];
        int pPos2 = -1; // Totally absent
        int pPos = [strPos intValue];
        NSUInteger pos = [strPos rangeOfString:@"-"].location;
        if (pos != NSNotFound)
            pPos2 = [[strPos substringFromIndex:pos+1] intValue];
        NSString *aaFrom = nil, *aaTo = nil;
        
        NSString *aaChange = [row objectAtIndex:_aaChange];
        pos = [aaChange rangeOfString:@"/"].location;
        if (pos != NSNotFound)
        {
            aaFrom = [aaChange substringToIndex:pos];
            aaTo = [aaChange substringFromIndex:pos+1];
        }
        
        NSString *seqFrom = nil, *seqTo = nil;
    
        if (![[row objectAtIndex:_ref] isEqualToString:@"-"])
            seqFrom = [row objectAtIndex:_ref];
        if (![[row objectAtIndex:_alt] isEqualToString:@"-"])
            seqTo = [row objectAtIndex:_alt];
        
        if ([self processMutation:geneId atPosition:pPos toPosition:pPos2 fromAa:aaFrom toAA:aaTo fromSeq:seqFrom toSeq:seqTo])
            successCounter++;
        
        if ([self hasToUpdateProgress:counter])
        {
            BOOL hasToCancelOperation = [_delegate updateProgressTo:[_inFile getPos]/(float)_inFile.length*100.0];
            
            if (hasToCancelOperation)
            {
               dispatch_async(dispatch_get_main_queue(),
                           ^{
                               [_delegate operationDidCancel];
                           }); 
                break;
            }
        }
    }
    
    NSTimeInterval elapsed = -[start timeIntervalSinceNow];
    
    if (_flags.verbose)
        PrintfLog("%ld records (%ld successful) processed in %.2f seconds (%.2f records per second)\n", counter, successCounter, elapsed, counter/elapsed);
    return YES;
}

-(BOOL) ensureStringsEqualLength: (NSString *)str str2: (NSString *)str2 forId: (NSString *)geneId
{
    if ([str length] != [str2 length])
    {
        PrintfLog("Warning: %s and %s must be same length for %s \n", [str UTF8String], [str2 UTF8String], [geneId UTF8String]);
        return NO;
    }
    return YES;
}

-(BOOL)ensureSingleAaChange: (NSString *)aa1 aa2: (NSString *)aa2 forId: (NSString *)geneId
{
    if (aa1) // Ensure 1 -> 1 aa change
    {
        if ([aa1 length] != 1 || [aa2 length] != 1)
        {
            PrintfLog("Warning: ignoring more than 1->1 aa change for %s/%s for %s\n", [aa1 UTF8String], [aa2 UTF8String], [geneId UTF8String]);
            return NO;
        }
    }
    return YES;
}

-(BOOL)ensureEqualAaChange: (NSString *)aa1 aa2: (NSString *)aa2 forId: (NSString *)geneId
{
    if (aa1) // Ensure 1 -> 1 aa change
    {
        if ([aa1 length] != [aa2 length])
        {
            PrintfLog("Warning: ignoring not equal aa change for %s/%s for %s\n", [aa1 UTF8String], [aa2 UTF8String], [geneId UTF8String]);
            return NO;
        }
    }
    return YES;
}

-(AminoAcid *)getAa: (NSString *)seq atPosition: (int) pos forId: (NSString *)geneId
{
    if ([seq length] < pos+3)
    {
        PrintfLog("Warning: here is no amino acid at position %d for %s; whole length is %ld\n", pos, [geneId UTF8String], [seq length                                                                                                                                   ]);
        return nil;
    }
    
    AminoAcid *aa = [[AminoAcid alloc] initWithString:seq position:pos];
    if (!aa || !aa.name)
    {
        PrintfLog("Warning: ignoring unknown amino acid %s for %s \n", [[seq substringWithRange:NSMakeRange(pos, 3)] UTF8String], [geneId UTF8String]);
        return nil;
    }
    return aa;
}

-(BOOL)checkAa: (AminoAcid *)aa mutation: (AminoAcid *)mut withAaFrom: (NSString *)aaFrom aaTo: (NSString *)aaTo atPosition: (int) pos forId: (NSString *)geneId
{
    if (!aaFrom) // No aa change, acid must remain same
    {
        if (mut.name != aa.name)
        {
            PrintfLog("Warning: ignoring incorrect mutation %s: no aa change recorded but occured\n", [geneId UTF8String]);
            return NO;
        }
    } else // Have change
    {
        if (mut.name != [aaTo characterAtIndex:pos])
        {
            PrintfLog("Warning: ignoring incorrect mutation %s:  %c change recorded but %c occured\n", [geneId UTF8String], [aaTo characterAtIndex:0], mut.name);
            return NO;
        }
    }
    return YES;
}

-(void) changeName: (GeneSequenceObj *)seq fromAa: (NSString *)aaFrom toAA: (NSString *)aaTo fromSeq: (NSString *)seqFrom toSeq: (NSString *)seqTo
{
    NSString *aaChange = @"-";
    if (aaFrom)
        aaChange = [NSString stringWithFormat:@"%@/%@", aaFrom, aaTo];
    NSString *pFrom = @"-";
    if (seqFrom)
        pFrom = seqFrom;
    NSString *pTo = @"-";
    if (seqTo)
        pTo = seqTo;
    
    seq.name = [NSString stringWithFormat:@"%@ %@ %@/%@", seq.name, aaChange, seqFrom, seqTo];
}

-(bool) processMutation: (NSString *)geneId atPosition: (int)pPos toPosition: (int)pPos2 fromAa: (NSString *)aaFrom toAA: (NSString *)aaTo fromSeq: (NSString *)seqFrom toSeq: (NSString *)seqTo
{
    // pPos = initial aa number; if pPos2 < 0, ppos is single (like 13); if pPos2 = 0 it is unknown (13-?) else it is range (13-15)
    // aaFrom can be nil = no aa chenge or both aaFrom and aaTo must be valid (N/D)
    // seqFrom = null means insertion; seqTo = null means deletion; else replacement occurs
    
    GeneSequenceObj *ref = [_reference objectForKey:geneId];
    if (!ref)
    {
        PrintfLog("Warning: record %s not found in reference file, ignoring...\n", [geneId UTF8String]);
        return false;
    }
    GeneSequenceObj *tRef = [_transReference objectForKey:geneId];
    if (!tRef)
    {
        PrintfLog("Warning: record %s not found in trans reference file, ignoring...\n", [geneId UTF8String]);
        return false;
    }
    int seqPos = (pPos-1)*3;
    if (seqFrom && seqTo) // Replacement
    {
        // Variant 1: one -> one mutation, no or one aa change
        if([seqFrom length] == 1)
        {
            if (![self ensureStringsEqualLength:seqFrom str2:seqTo forId:geneId])
                return false;
            if (![self ensureSingleAaChange:aaFrom aa2:aaTo forId:geneId])
                return false;
            AminoAcid *aa = [self getAa: ref.seq atPosition:seqPos forId:geneId];
            if (!aa)
                return false;
            NSArray<AminoAcid *> *mutArray = [aa mutate:[seqFrom characterAtIndex:0] to:[seqTo characterAtIndex:0]];
            if ([mutArray count] == 0)
            {
                PrintfLog("Warning: can't mutate %s->%s as no such nucleotide exists in %s for %s \n", [seqFrom UTF8String], [seqTo UTF8String], [[aa seq] UTF8String], [geneId UTF8String]);
                return false;
            }
            AminoAcid *mut = [mutArray objectAtIndex:0];
            if ([mutArray count] == 2) // Have to decide wich one is correct analyzing aachange
            {
                if (!aaFrom) // No aa change, acid must remain same
                {
                    if ([[mutArray objectAtIndex:1] name] == aa.name) // 2nd!
                    {
                        mut = [mutArray objectAtIndex:1];
                        if ([[mutArray objectAtIndex:0] name] == aa.name) // 1t too :0
                            PrintfLog("Warning: more than one variant for %s, ignoring for now...\n", [geneId UTF8String]);
                    }
                } else // Have change, check if 2nd fits
                {
                    if ([[mutArray objectAtIndex:1] name] == [aaTo characterAtIndex:0]) // 2nd!
                    {
                        mut = [mutArray objectAtIndex:1];
                        if ([[mutArray objectAtIndex:0] name] == [aaTo characterAtIndex:0]) // 1t too :0
                            PrintfLog("Warning: more than one variant for %s, ignoring for now...\n", [geneId UTF8String]);
                    }
                }
                // TODO: do not ignore variants when both fits
            }
            if (![self checkAa:aa mutation:mut withAaFrom:aaFrom aaTo:aaTo atPosition:0 forId:geneId])
                return false;
            
            // All OK, mutate & dump results...
            GeneSequenceObj *mutSeq = [ref replaceSequence:[mut seq] atPosition:seqPos];
            if (_flags.verbose)
                PrintfLog("%s: single replacement at position %d (%s->%s) = (%s->%s)", [geneId UTF8String], pPos, [seqFrom UTF8String], [seqTo UTF8String], [[aa seq] UTF8String], [[mut seq] UTF8String]);
            
            GeneSequenceObj *mutTrans = tRef;
            if (aaFrom)
            {
                mutTrans = [mutTrans replaceSequence:aaTo atPosition:pPos-1];
                if (_flags.verbose)
                    PrintfLog(", AA change: %s/%s", [aaFrom UTF8String], [aaTo UTF8String]);
            }
            if (_flags.verbose)
                PrintfLog("\n");
            
            [self changeName:mutSeq fromAa:aaFrom toAA:aaTo fromSeq:seqFrom toSeq:seqTo];
            [self changeName:mutTrans fromAa:aaFrom toAA:aaTo fromSeq:seqFrom toSeq:seqTo];
            [_outFile write:mutSeq];
            [_transOutFile write:mutTrans];
            return true;
        }
        // Variant 2: two -> two mutation, one aa affected, no or one aa change
        if([seqFrom length] == 2 && pPos2 <= 0)
        {
            if (![self ensureStringsEqualLength:seqFrom str2:seqTo forId:geneId])
                return false;
            if (![self ensureSingleAaChange:aaFrom aa2:aaTo forId:geneId])
                return false;
            AminoAcid *aa = [self getAa: ref.seq atPosition:seqPos forId:geneId];
            if (!aa)
                return false;
            AminoAcid *mut= [aa mutate2: seqFrom to: seqTo];
            if (!mut || !mut.name)
            {
                PrintfLog("Warning: can't mutate %s->%s as no such nucleotides exist in %s for %s \n", [seqFrom UTF8String], [seqTo UTF8String], [[aa seq] UTF8String], [geneId UTF8String]);
                return false;
            }
            if (![self checkAa:aa mutation:mut withAaFrom:aaFrom aaTo:aaTo  atPosition:0 forId:geneId])
                return false;
            
            // All OK, mutate & dump results...
            GeneSequenceObj *mutSeq = [ref replaceSequence:[mut seq] atPosition:seqPos];
            if (_flags.verbose)
                PrintfLog("%s: double replacement at position %d (%s->%s) = (%s->%s)", [geneId UTF8String], pPos, [seqFrom UTF8String], [seqTo UTF8String], [[aa seq] UTF8String], [[mut seq] UTF8String]);
            GeneSequenceObj *mutTrans = tRef;
            if (aaFrom)
            {
                mutTrans = [mutTrans replaceSequence:aaTo atPosition:pPos-1];
                if (_flags.verbose)
                    PrintfLog(", AA change: %s/%s", [aaFrom UTF8String], [aaTo UTF8String]);
            }
            if (_flags.verbose)
                PrintfLog("\n");
            
            [self changeName:mutSeq fromAa:aaFrom toAA:aaTo fromSeq:seqFrom toSeq:seqTo];
            [self changeName:mutTrans fromAa:aaFrom toAA:aaTo fromSeq:seqFrom toSeq:seqTo];
            [_outFile write:mutSeq];
            [_transOutFile write:mutTrans];
            return true;
        }
        // Variant 3: two -> two mutation, two aa affected for 0 to 2 aa changes
        if([seqFrom length] == 2 && pPos2 > 0)
        {
            if (![self ensureStringsEqualLength:seqFrom str2:seqTo forId:geneId])
                return false;
            
            int seqPos2 = (pPos2-1)*3;
            if ((pPos2 - pPos) != 1)
            {
                PrintfLog("Warning: 2->2 replacement requires 2 consequent amino acid position for %s, while having %d and %d\n", [geneId UTF8String], pPos, pPos2);
                return false;
            }
            
            if (![self ensureEqualAaChange:aaFrom aa2:aaTo forId:geneId])
                return false;
            // If change occurs it should be 1 or 2
            if (aaFrom)
                if ([aaFrom length] > 2)
                {
                    PrintfLog("Warning: can't mutate %ld amino acids as maximum is 2 for %s \n", [aaFrom length], [geneId UTF8String]);
                    return false;
                }
            
            AminoAcid *aa1 = [self getAa: ref.seq atPosition:seqPos forId:geneId];
            if (!aa1)
                return false;
            AminoAcid *aa2 = [self getAa: ref.seq atPosition:seqPos2 forId:geneId];
            if (!aa2)
                return false;
            AminoAcid *mut1 = [aa1 mutate: [seqFrom characterAtIndex:0] to: [seqTo characterAtIndex:0] atPosition:2];
            if (!mut1 || !mut1.name)
            {
                PrintfLog("Warning: can't mutate %c->%c at 3rd nucleotide of %s for %s \n", [seqFrom characterAtIndex:0], [seqTo characterAtIndex:0], [[aa1 seq] UTF8String], [geneId UTF8String]);
                return false;
            }
            AminoAcid *mut2 = [aa2 mutate: [seqFrom characterAtIndex:1] to: [seqTo characterAtIndex:1] atPosition:0];
            if (!mut2 || !mut2.name)
            {
                PrintfLog("Warning: can't mutate %c->%c at 1st nucleotide of %s for %s \n", [seqFrom characterAtIndex:1], [seqTo characterAtIndex:1], [[aa2 seq] UTF8String], [geneId UTF8String]);
                return false;
            }
            
            // HERE SHOULD CHECK aa change
            if (![self checkAa:aa2 mutation:mut2 withAaFrom:aaFrom aaTo:aaTo atPosition:1 forId:geneId])
                return false;
            if (![self checkAa:aa1 mutation:mut1 withAaFrom:aaFrom aaTo:aaTo atPosition:0 forId:geneId])
                return false;
            
            // All OK, mutate & dump results...
            GeneSequenceObj *mutSeq = [ref replaceSequence:seqTo atPosition:seqPos];
            if (_flags.verbose)
                PrintfLog("%s: double replacement at position %d (%s->%s) = (%s%s->%s%s)", [geneId UTF8String], pPos, [seqFrom UTF8String], [seqTo UTF8String], [[aa1 seq] UTF8String], [[aa2 seq] UTF8String], [[mut1 seq] UTF8String], [[mut2 seq] UTF8String]);
            
            GeneSequenceObj *mutTrans = tRef;
            if (aaFrom)
            {
                mutTrans = [mutTrans replaceSequence:aaTo atPosition:pPos-1];
                if (_flags.verbose)
                    PrintfLog(", AA change: %s/%s", [aaFrom UTF8String], [aaTo UTF8String]);
            }
            if (_flags.verbose)
                PrintfLog("\n");
            
            [self changeName:mutSeq fromAa:aaFrom toAA:aaTo fromSeq:seqFrom toSeq:seqTo];
            [self changeName:mutTrans fromAa:aaFrom toAA:aaTo fromSeq:seqFrom toSeq:seqTo];
            [_outFile write:mutSeq];
            [_transOutFile write:mutTrans];
            return true;
            
        }
        PrintfLog("Warning: more that 2->2 replacements are not supported for %s\n", [geneId UTF8String]);
        return false;
    } else if (seqFrom) // Deletion
    {
        // We don't know exact location, it should start in given amino acid (seqPos..seqPos+3)
        if ([ref.seq length] < seqPos+3) // Ups
        {
            PrintfLog("Warning: not enough data in %s to make deletion: whole length is %ld while we are trying to delete from %d\n", [geneId UTF8String], [ref.seq length], seqPos);
            return false;
        }
        
        // Find...
        NSRange r = [ref.seq rangeOfString:seqFrom options: 0 range:NSMakeRange(seqPos, [ref.seq length] -seqPos)];
        if (r.location == NSNotFound)
        {
            PrintfLog("Warning: can't delete %s at position %d for %s as it is not found\n", [seqFrom UTF8String], seqPos, [geneId UTF8String]);
            return false;
        }
        if (r.location - seqPos >= 3)
        {
            PrintfLog("Warning: can't delete %s at position %d for %s as it not found at given amino acid position\n", [seqFrom UTF8String], seqPos, [geneId UTF8String]);
            return false;
        }
        
        GeneSequenceObj *mutSeq = [ref deleteSequenceAtPosition:r.location withLength:[seqFrom length]];
        if (_flags.verbose)
            PrintfLog("%s: deletion at position %ld (%s)\n", [geneId UTF8String], r.location, [seqFrom UTF8String]);
        [self changeName:mutSeq fromAa:aaFrom toAA:aaTo fromSeq:seqFrom toSeq:seqTo];
        [_outFile write:mutSeq];
        return true;
    } else  // Insertion
    {
        GeneSequenceObj *mutSeq = [ref insertSequence:seqTo atPosition:seqPos];
        if (_flags.verbose)
            PrintfLog("%s: insertion at position %d (%s)\n", [geneId UTF8String], pPos, [seqTo UTF8String]);
        [self changeName:mutSeq fromAa:aaFrom toAA:aaTo fromSeq:seqFrom toSeq:seqTo];
        [_outFile write:mutSeq];
        return true;
    }
}


@end

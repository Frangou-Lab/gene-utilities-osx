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

@interface GeneSequenceObj : NSObject

@property (copy, nonatomic) NSString *name;
@property (copy, nonatomic) NSString *desc;
@property (copy, nonatomic) NSString *seq;
@property (copy, nonatomic) NSString *quality;

-(id)initWithName: (NSString *)_name desription: (NSString *)_desc sequence: (NSString *)seq;
-(id)initWithName: (NSString *)_name desription: (NSString *)_desc sequence: (NSString *)seq quality: (NSString *)qual;

-(id) replaceSequence: (NSString *)repl atPosition: (int)pos;
-(id) deleteSequenceAtPosition: (NSUInteger)pos withLength: (NSUInteger)len;
-(id) insertSequence: (NSString *)repl atPosition: (int)pos;

@end

@interface AminoAcid: NSObject
{
    char _seq[4];
}

@property char name;

-(id)initWithNucleotides: (const char *)seq;
-(id)initWithNucleotides: (const char *)seq mutation: (char)mutated atPosition: (int) pos;
-(id)initWithNucleotide: (char) _1 _2: (char)_2 _3: (char) _3;
-(id)initWithString: (NSString *)aa;
-(id)initWithString: (NSString *)aa position:(int)position;

-(AminoAcid *)mutate2: (NSString *)nucleotides to:(NSString *) nucleotides2;
-(NSArray <AminoAcid *> *)mutate: (char)nucleotide to:(char) nucleotide2;
-(AminoAcid *)mutate: (char)nucleotide to:(char) nucleotide2 atPosition: (int) pos;
-(NSString *)seq;

@end

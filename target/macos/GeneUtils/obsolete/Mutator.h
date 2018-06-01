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
#import "SequenceFileObj.h"
#import "OperationObj.h"

@interface Mutator : OperationObj
{
    SequenceFileObj *_refFile, *_transRefFile;
    SequenceFileObj *_outFile, *_transOutFile;
    
    SeparatedFileObj *_inFile;
    
    NSMutableDictionary<NSString *, GeneSequenceObj *> *_reference, *_transReference;
    
    // Needfull columns
    int _gene, _geneSymbol, _transcript, _proteinPos, _aaChange, _alt, _ref;
}

- (id)initWithInput: (const char *)input reference: (const char *)ref transReference: (const char *)tRef flags: (CommandLineFlagsObj*)flags;
- (id)initWithInput:(const char *)input reference:(const char *)ref transReference:(const char *)tRef outReference:(NSString *)outReference outTransReference:(NSString *)outTransReference flags:(CommandLineFlagsObj*)flags;

@end

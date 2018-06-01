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

@class GeneSequenceObj;

@interface SequenceFileObj : InOutFile

+(NSSet<NSString *> *)extensions;
+(NSString *)defaultExtension;

+ (NSArray<NSString*> *)supportedFileFormats;
+ (NSArray<NSString*> *)defaultFileFormats;

+(enum FileType)extension2type: (NSString *)str;
+(NSString *)type2extension: (enum FileType)type;
+(enum FileType)str2type: (NSString *)str;
+(NSString *)type2str: (enum FileType)type;
+(NSString *)str2extension:(NSString *)str;
+(NSString *)extension2str:(NSString *)ext;

-(NSString *)strFileType;

-(BOOL)isValidGeneFile;

-(GeneSequenceObj *)read;
-(void)write: (GeneSequenceObj *)seq;

@end

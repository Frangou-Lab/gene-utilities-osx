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

@interface CommandLineFlagsObj: NSObject
{
    NSMutableDictionary<NSString *, NSString *> *dict;
    BOOL _verbose;
}

-(id)init;
-(id)initWithArguments: (const char **)argv number: (int)argc atPosition: (int *)pStart;
+(id)flagsWithArguments: (const char **)argv number: (int)argc atPosition: (int *)pStart;
-(enum FileType)inputFormat;
-(enum FileType)outputFormat;
-(char)quality;

-(BOOL)checkSetting: (NSString *)name;
-(int)getIntSetting: (NSString *)name; // Returns 0 if no setting exists or it is invalid
-(NSString *)getSetting: (NSString *)name; // Returns nil if no setting exists

- (void)setSetting: (NSString *)value withKey: (NSString *)key;

@property BOOL verbose;

@end

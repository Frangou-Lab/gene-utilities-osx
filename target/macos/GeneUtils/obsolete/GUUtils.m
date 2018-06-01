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

#import "GUUtils.h"

@implementation GUUtils

+ (void)showAlertWithMessage:(NSString *)message andImageNamed:(NSString *)imageName
{
    NSAlert *alert = [NSAlert new];
    alert.messageText = message;
    alert.informativeText = @" ";
    alert.icon = [NSImage imageNamed:imageName];
    alert.alertStyle = NSAlertStyleInformational;
    [alert runModal];
}

+ (NSString *)fileNameFromPath:(NSString *)filePath
{
    if ([[filePath pathExtension] isEqualToString:@"gz"])
        return [[[filePath lastPathComponent] stringByDeletingPathExtension] stringByDeletingPathExtension];
    else
        return [[filePath lastPathComponent] stringByDeletingPathExtension];
}

+ (NSString *)fileNameFromUrl:(NSURL *)filePath
{
    if ([[filePath pathExtension] isEqualToString:@"gz"])
        return [[[filePath lastPathComponent] stringByDeletingPathExtension] stringByDeletingPathExtension];
    else
        return [[filePath lastPathComponent] stringByDeletingPathExtension];
}


+ (NSString *)pathExtensionFromString:(NSString *)filePath
{
    if ([[filePath pathExtension] isEqualToString:@"gz"])
        return [[filePath stringByDeletingPathExtension] pathExtension];
    else
        return [filePath pathExtension];
}

+ (NSString *)pathExtensionFromUrl:(NSURL *)filePath
{
    if ([[filePath pathExtension] isEqualToString:@"gz"])
        return [[filePath URLByDeletingPathExtension] pathExtension];
    else
        return [filePath pathExtension];
}

@end

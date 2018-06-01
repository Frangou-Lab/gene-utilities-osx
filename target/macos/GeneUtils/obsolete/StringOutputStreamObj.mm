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

#import "StringOutputStreamObj.h"

@implementation StringOutputStreamObj

-(id)initWithFileName:(const char *)file
{
    if (self = [super init])
    {
        m_file = fopen(file, "wt");
        if (!m_file)
        {
            return nil;
        }
        m_length = 0;
    }
    return self;
    
}

-(long)getPos
{
    return m_length;
}

-(void)setPos:(long)pos
{
}

-(void)writeString:(NSString *)str
{
    fputs([str UTF8String], m_file);
    fputc('\n', m_file);
    m_length += [str length] + 1;
}

-(void)write:(NSString *)str
{
    fputs([str UTF8String], m_file);
    m_length += [str length];
}

-(void)writeChar:(char)chr
{
    fputc(chr, m_file);
    m_length ++;
}

@end

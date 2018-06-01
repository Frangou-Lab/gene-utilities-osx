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

#ifndef GUProgressWindowController_h
#define GUProgressWindowController_h

enum class GUProgressWindowMode {
    Indeterminate = 0,
    Determinate,
    DeterminateMultipleJobs
};

@interface GUProgressWindowController : NSWindowController

@property (nonatomic) long numberOfFiles;
@property (nonatomic) bool timeEstimationEnabled;

- (void)showProgessWindowWithMode:(GUProgressWindowMode)mode;
- (bool)dismissProgressViewController;
- (void)resetController;
- (void)setNumberOfCurrentFile:(NSInteger)currentNumber;
- (void)setStatus:(NSString *)statusText;
- (bool)setProgress:(float)percent;
- (bool)cancelWasClicked;
- (void)cancelCurrentTask;

@end

#endif  // GUProgressWindowController_h

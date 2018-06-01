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

#import "ColumnType.h"

enum HistoryEntryKind
{
	HDV_FILTER,
	HDV_RANK_COLUMNS,
	HDV_TRANSPOSE,
	HDV_ID2FREQ,
	HDV_FREQ2ID,
	HDV_GENE_FINGERPRING_LIST_OF_GENES,
	HDV_GENE_FINGERPRING_COUNT,
	HDV_REORDER,
	HDV_PERCENTILES,
	HDV_RESAMPLER_OUTPUT,
	HDV_RESAMPLER_SUMMARY,
	HDV_SPECIAL_APPLY_FUNCTION,
	HDV_SPECIAL_LARGEST_VALUE,
	HDV_MERGE,
	HDV_BATCH_MERGE,
	HDV_WILDCARD_EXTRACT,
	HDV_CALC_FREQ_TABLE_FOR_ALL_FILES_BY_COLUMN,
	HDV_CALC_FREQ_TABLE,
	HDV_EXTRACT,
	HDV_TRANSFORM,
	HDV_SEARCH,
	HDV_ROW_COLUMN_STATISTIC,
	HDV_REMOVE_DUPLICATES,
    HDV_SPLIT
};
@interface ColumnTypeWrapper: NSObject
{
	NSString* description;
	int columnId;
	enum ColumnType type;
	NSMutableArray* groups;

}
@property(retain) NSString* description;
@property(assign) int columnId;
@property(retain) NSMutableArray* groups;
@property(assign) enum ColumnType type;

-(id) initWithId:(int)columnId_ description: (NSString*) description_ type: (enum ColumnType) type_;
+(id) columnWithId:(int)columnId_ description: (NSString*) description_ type: (enum ColumnType) type_;

@end

@interface GroupWrapper: NSObject
{
	NSString* groupName;
	NSMutableArray* columns; // ColumnWrapper
	NSColor *color;
}
@property(retain) NSString* groupName;
@property(readonly, retain) NSMutableArray* columns;
@property(retain) NSColor *color;

-(id) initWithDictionary: (NSDictionary* ) dictionary;
+(id) groupWithDictionary:(NSDictionary*)dictionary;
-(id) initWithName:(NSString*)groupName_ color: (NSColor*) color_ ;
+(id) groupWithName:(NSString*)groupName_ color: (NSColor*) color_;
-(NSDictionary*) asDictionary;

@end

@interface HistoryEntry: NSObject
{
	enum HistoryEntryKind m_kind;
	NSString* m_description;
}
-(id) initWithEntryKind: (enum HistoryEntryKind) kind withDescription: (NSString*) description;
+(id) entryWithKind: (enum HistoryEntryKind) kind withDescription: (NSString*) description;
-(NSString*) toString;
-(NSString*) operation;
-(NSString*) description;
@property(readonly) enum HistoryEntryKind m_kind;
@property(readonly) NSString* m_description;

@end

@interface ColumnTypesConfiguration : NSObject {
	NSMutableArray* m_columns;
	NSMutableArray* m_groups;
	NSMutableArray* m_history;
}
@property(readwrite, retain) NSMutableArray* m_history;

-(void)saveConfigurationOfColumnTypesForFile:(NSString*) inputFile;
-(void)readConfigurationOfColumnTypesForFile:(NSString*) inputFile;
-(void)addColumn: (int) columnId  withType: (enum ColumnType) type withDescription:(NSString*)description;
-(void)addColumnWithType: (enum ColumnType) type withDescription:(NSString*)description;
-(void)addColumn: (int) columnId toGroup:(NSString*) groupName;
-(void)addGroup: (NSString*) name withColor:(NSColor*) color;
-(GroupWrapper*)getGroupByName: (NSString*) groupName;
-(ColumnTypeWrapper *)getColumnById: (int) columnId;
-(NSArray*)getAllColumnsByGroupName:(NSString*) groupName;
-(NSArray*) columnsWithType:(enum ColumnType) type;
//return sorted array of ints
-(NSArray*) sortedColumnIdsWithType:(enum ColumnType) type;
-(NSArray*) columns;
-(NSArray*) groups;
-(int) columnIdEnumerateAssumeExcludeIDColumn: (int) columnId;
-(ColumnTypeWrapper *) IDColumn;
-(id) init;
+(ColumnTypesConfiguration*) configuration;
-(bool) column: (int) columnId hasType: (enum ColumnType) type;
-(ColumnTypesConfiguration *) makeCopy;
-(void) copyHistoryFromConfiguration: (ColumnTypesConfiguration*) configuration;
-(void) addHistoryEntry: (enum HistoryEntryKind) kind withDescription: (NSString*) description;
-(void) addHistoryEntry: (enum HistoryEntryKind) kind;

+(NSString *)id2string: (enum ColumnType)type;
+(enum ColumnType)string2id: (NSString *)type;

@end

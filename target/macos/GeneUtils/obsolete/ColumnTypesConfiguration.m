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

#import "ColumnTypesConfiguration.h"

@implementation ColumnTypeWrapper

@synthesize description;
@synthesize columnId;
@synthesize groups;
@synthesize type;

-(id) initWithId:(int)columnId_ description:(NSString *)description_ type:(enum ColumnType)type_
{
	if (self = [super init])
	{
		self.description = description_;
		self.columnId = columnId_;
		self.type = type_;
	}
	return self;
}
+(id) columnWithId:(int)columnId_ description: (NSString*) description_ type: (enum ColumnType) type_
{
	ColumnTypeWrapper* column = [[ColumnTypeWrapper alloc] initWithId:columnId_ description:description_ type: type_];
    return column;
}

@end

static const NSString* ALPHA_COMPONENT_KEY = @"alpha";
static const NSString* RED_COMPONENT_KEY = @"red";
static const NSString* GREEN_COMPONENT_KEY = @"green";
static const NSString* BLUE_COMPONENT_KEY = @"blue";
static const NSString* NAME_KEY = @"name";
static const NSString* COLOR_KEY = @"color";

@implementation GroupWrapper

@synthesize groupName;
@synthesize columns;
@synthesize color;

-(id) init
{
	if (self = [super init])
	{
		columns = [[NSMutableArray alloc] init];		
	}
	return self;
}
-(id) initWithName:(NSString*)groupName_ color:(NSColor *)color_ 
{
    if (self = [self init])
	{
		self.groupName = groupName_;
		self.color = color_;
	}
	return self;
}
//without init relations between groups & columns
-(id) initWithDictionary: (NSDictionary* ) dictionary
{
	if (!dictionary)
	{
		return nil;
	}
	if (self = [self init])
	{
		self.groupName = [dictionary objectForKey: NAME_KEY];
		NSDictionary* colorDictionary = [dictionary objectForKey: COLOR_KEY];
		if (nil != colorDictionary)
		{
			CGFloat alpha = [[colorDictionary objectForKey: ALPHA_COMPONENT_KEY] doubleValue];
			CGFloat red = [[colorDictionary objectForKey: RED_COMPONENT_KEY] doubleValue];
			CGFloat green = [[colorDictionary objectForKey: GREEN_COMPONENT_KEY] doubleValue];
			CGFloat blue = [[colorDictionary objectForKey: BLUE_COMPONENT_KEY] doubleValue];
			self.color = [NSColor colorWithDeviceRed: red green: green blue: blue alpha: alpha];
		}
	}
	return self;
}
+(id) groupWithName:(NSString*)groupName_ color:(NSColor *)color_
{
	GroupWrapper *gw = [[GroupWrapper alloc] initWithName: groupName_ color: color_];
    return gw;
}

+(id) groupWithDictionary:(NSDictionary*)dictionary
{
	GroupWrapper *gw = [[GroupWrapper alloc] initWithDictionary: dictionary];
    return gw;
}

//without store relation
-(NSDictionary*) asDictionary
{
	NSDictionary* colorForDictionary = [NSDictionary dictionaryWithObjectsAndKeys: 
											[NSNumber numberWithDouble:[color alphaComponent]], ALPHA_COMPONENT_KEY,
											[NSNumber numberWithDouble:[color redComponent]], RED_COMPONENT_KEY,
											[NSNumber numberWithDouble:[color greenComponent]], GREEN_COMPONENT_KEY,
											[NSNumber numberWithDouble:[color blueComponent]], BLUE_COMPONENT_KEY,
										nil];
	return [NSDictionary dictionaryWithObjectsAndKeys: 
			groupName, NAME_KEY,
			colorForDictionary, COLOR_KEY,
			nil];
}
@end

static const NSString* ROOT_KEY = @"column_types";
static const NSString* COLUMNS_KEY = @"columns";
static const NSString* GROUPS_KEY = @"groups";
static const NSString* ID_KEY = @"id";
static const NSString* TYPE_KEY = @"type";
static const NSString* DESCRIPTION_KEY = @"description";

static const NSString* HISTORY_DESCRIPTION_KEY = @"history_description";
static const NSString* HISTORY_KIND_KEY = @"history_kind";
static const NSString* HISTORIES_KEY = @"histories";

@implementation ColumnTypesConfiguration

@synthesize m_history;

+(NSString *)id2string: (enum ColumnType)type
{
    switch (type) {
        case ID:
            return @"#(Id)";
        case Desc:
            return @"I(nfo)";
        case Filter:
            return @"F(ilter)";
        case Data:
            return @"D(ata)";
        case Exclude:
            return @"E(xclude)";
        case Search:
            return @"S(earch)";
        default:
            return @"?(Undefined)";
    }
}
+(enum ColumnType)string2id: (NSString *)type
{
    if ([type length] < 1)
        return Undefined;
    switch ([type characterAtIndex:0])
    {
        case '#':
            return ID;
        case 'I':
            return Desc;
        case 'F':
            return Filter;
        case 'D':
            return Data;
        case 'E':
            return Exclude;
        case 'S':
            return Search;
        default:
            return Undefined;
    }
}

-(NSArray*) columns
{
	return m_columns;
}
-(NSArray*) groups
{
	return m_groups;
}
-(id) init
{
	if (self = [super init])
	{
		m_columns = [[NSMutableArray alloc] initWithCapacity: 0];
		m_groups = [[NSMutableArray alloc] initWithCapacity: 0];
		m_history = [[NSMutableArray alloc] initWithCapacity: 0];
	}
	return self;
}

+(ColumnTypesConfiguration*) configuration
{
    return [[ColumnTypesConfiguration alloc] init];
}

-(void)saveConfigurationOfColumnTypesForFile:(NSString*) inputFile
{
    @autoreleasepool {
	if (nil == inputFile)
	{
		return;
	}	
	NSString* plistPath = [[inputFile stringByDeletingPathExtension] stringByAppendingPathExtension:@"ctp"];
	assert(nil != m_columns);
	NSMutableArray* allColumns = [NSMutableArray arrayWithCapacity: [m_columns count]];
	for (int i = 0; i < (int)[m_columns count]; i++)
	{
		ColumnTypeWrapper* columnTypeWrapper = [m_columns objectAtIndex: i];
		NSDictionary* column = [NSDictionary dictionaryWithObjectsAndKeys:
											[NSNumber numberWithInteger: [columnTypeWrapper columnId]], ID_KEY,
											[NSNumber numberWithInteger: [columnTypeWrapper type]], TYPE_KEY,
											[columnTypeWrapper description], DESCRIPTION_KEY,
										  nil];
		[allColumns addObject: column];
	}
	assert(nil != m_groups);
	NSMutableArray* allGroups = [NSMutableArray arrayWithCapacity: [m_groups count]];
	for (GroupWrapper* groupWrapper in m_groups)
	{
		NSMutableDictionary* groupDictionary = [NSMutableDictionary dictionaryWithDictionary: [groupWrapper asDictionary]];
		NSMutableArray* columnsForDictionary = [NSMutableArray array];
		for (ColumnTypeWrapper* column in [groupWrapper columns])
		{
			[columnsForDictionary addObject: [NSNumber numberWithInt: [column columnId]]];
		}
		[groupDictionary setObject: columnsForDictionary forKey:COLUMNS_KEY];	
		[allGroups addObject: groupDictionary];
	}
	assert (nil != m_history);
	NSMutableArray* allHistories = [NSMutableArray arrayWithCapacity: [m_history count]];
	for (HistoryEntry* historyEntry in m_history)
	{
		NSDictionary* historyDictionary = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInt: [historyEntry m_kind]], HISTORY_KIND_KEY, 
		 [historyEntry m_description], HISTORY_DESCRIPTION_KEY, nil];
		[allHistories addObject: historyDictionary];		
	}
		
	NSDictionary* root = [NSDictionary dictionaryWithObjectsAndKeys: allColumns, COLUMNS_KEY, allGroups, GROUPS_KEY, allHistories, HISTORIES_KEY, nil];
	NSDictionary* dictionary = [NSDictionary dictionaryWithObjectsAndKeys: root, ROOT_KEY, nil];
	
	NSError *error;
        
    NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:dictionary format:NSPropertyListXMLFormat_v1_0 options:0 error: &error];

    if(plistData)
	{
        NSError* writeToFileError;
		if (![plistData writeToFile:plistPath  options:NSDataWritingAtomic error:&writeToFileError])
		{
			NSLog(@"Error writing plist: %@", [writeToFileError localizedDescription]);
		}
    }
    else
	{
        NSLog(@"Error writing plist: %@", error);
    }
    }
}

-(void)readConfigurationOfColumnTypesForFile:(NSString*) inputFile
{
    @autoreleasepool {
	NSError *error = nil;
	NSPropertyListFormat format;
	NSString* plistPath = [[inputFile stringByDeletingPathExtension] stringByAppendingPathExtension:@"ctp"];
	bool isFileExist = [[NSFileManager defaultManager] fileExistsAtPath:plistPath];
	if (!isFileExist)
	{
		return;
	}
	NSData *plistXML = [[NSFileManager defaultManager] contentsAtPath:plistPath];
	NSDictionary *configuration = (NSDictionary *)[ NSPropertyListSerialization
												   propertyListWithData:plistXML options:0 format:&format error:&error];
	if (!configuration) 
	{
		NSLog(@"Error reading plist: %@, format: %lu", error, format);
		return;
	}
	NSDictionary* root = [configuration objectForKey: ROOT_KEY];
	NSArray* allColumns = [root objectForKey: COLUMNS_KEY];
	for (NSDictionary* column in allColumns)
	{
		int columnId = [[column objectForKey: ID_KEY] intValue];
		int type = [[column objectForKey: TYPE_KEY] intValue];
		NSString* description = [column objectForKey: DESCRIPTION_KEY];
		ColumnTypeWrapper* columnWrapper = [ColumnTypeWrapper columnWithId: columnId description: description type:(enum ColumnType)type];
		[m_columns addObject: columnWrapper];
	}
	NSArray* allGroups = [root objectForKey: GROUPS_KEY];
	for (NSDictionary* groupDictionary in allGroups)
	{
		GroupWrapper* group = [GroupWrapper groupWithDictionary: groupDictionary ];
		[m_groups addObject: group];
		NSArray* columns = [groupDictionary objectForKey: COLUMNS_KEY];
		for (NSNumber* columnId in columns)
		{
			[self addColumn:[columnId intValue] toGroup:[group groupName]];			
		}
	}

	[m_history removeAllObjects];
	NSArray* allHistories = [root objectForKey: HISTORIES_KEY];
	for (NSDictionary* historyDictionary in allHistories)
	{
		enum HistoryEntryKind kind = (enum HistoryEntryKind)[[historyDictionary objectForKey: HISTORY_KIND_KEY] intValue];
		NSString* description = [historyDictionary objectForKey: HISTORY_DESCRIPTION_KEY];
		[m_history addObject: [HistoryEntry entryWithKind: kind withDescription: description]];
	}
    }
}
-(void)addColumn: (int) columnId toGroup:(NSString*) groupName
{
	id column = [self getColumnById: columnId];
	id group = [self getGroupByName: groupName];
	if (group && column)
	{
		[[group columns] addObject: column];
		[[column groups] addObject: group];
	}
}
-(NSArray*) columnsWithType:(enum ColumnType)type
{
	NSMutableArray* columnsWithSameType = [NSMutableArray array];
	for (ColumnTypeWrapper* column in  m_columns)
	{
		if (type == [column type])
		{
			[columnsWithSameType addObject: column];
		}
	}
	return columnsWithSameType;
}
-(NSArray*) sortedColumnIdsWithType:(enum ColumnType) type
{
	NSMutableArray* columnsWithSameType = [NSMutableArray array];
	for (ColumnTypeWrapper* column in  m_columns)
	{
		if (type == [column type])
		{
			[columnsWithSameType addObject: [NSNumber numberWithInt: [column columnId]]];
		}
	}
	NSSortDescriptor *sortDescription = [NSSortDescriptor sortDescriptorWithKey: @"intValue" ascending: TRUE];
	[columnsWithSameType sortUsingDescriptors: [NSArray arrayWithObject: sortDescription]];
	return columnsWithSameType;
}
-(GroupWrapper*)getGroupByName: (NSString*) groupName 
{
	if (nil == groupName)
	{
		return nil;
	}
	id group = nil;
	NSEnumerator *e = [m_groups objectEnumerator];
	while ((group = [e nextObject]) && ([[group groupName] caseInsensitiveCompare: groupName] != NSOrderedSame)) ;
	return group;	
}
-(ColumnTypeWrapper *)getColumnById: (int) columnId
{
	id column = nil;
	NSEnumerator *e = [m_columns objectEnumerator];
	while ((column = [e nextObject]) && ([column columnId] != columnId));
	return column;
}

-(NSArray*)getAllColumnsByGroupName:(NSString*) groupName
{
	id group = [self getGroupByName: groupName];
	if (nil == group)
	{
		return nil;
	}
	return [group columns];
}
-(void)addColumn: (int) columnId  withType: (enum ColumnType) type withDescription: (NSString*) description
{
	assert(nil != m_columns);
	[m_columns addObject: [ColumnTypeWrapper columnWithId:columnId description:description type:type]];
}
-(void)addColumnWithType: (enum ColumnType) type withDescription:(NSString*)description
{	
	assert(nil != m_columns);
	[m_columns addObject: [ColumnTypeWrapper columnWithId:(int)[m_columns count] description:description type:type]];
}
-(void)addGroup: (NSString*) name withColor:(NSColor*) color
{
	assert(nil != m_groups);
	[m_groups addObject: [GroupWrapper groupWithName: name color: color]];
}
-(int) columnIdEnumerateAssumeExcludeIDColumn: (int) columnId
{
	ColumnTypeWrapper* idColumn = [self IDColumn];
	return columnId <= [idColumn columnId] ? columnId : columnId - 1; 
}
-(ColumnTypeWrapper *) IDColumn
{
	NSArray* allIdColumns = [self columnsWithType: ID];
	if (![allIdColumns count])
		return nil;
	
	assert (1 == [allIdColumns count]);
	return [allIdColumns lastObject];
}
-(bool) column: (int) columnId hasType: (enum ColumnType) type
{
	return [[self getColumnById: columnId] type] == type;
}

-(ColumnTypesConfiguration *) makeCopy
{
	ColumnTypesConfiguration *cfg = [ColumnTypesConfiguration configuration];
	for (ColumnTypeWrapper *cw in m_columns)
	{
		[cfg addColumn:cw.columnId withType:cw.type withDescription:cw.description]; 
	}
	for (GroupWrapper *gw in m_groups)
	{
		[cfg addGroup:gw.groupName withColor:gw.color];
		for (ColumnTypeWrapper *cw in gw.columns)
			[cfg addColumn:cw.columnId toGroup:gw.groupName];
	}
	[cfg copyHistoryFromConfiguration: self];
	return cfg;
}
-(void) copyHistoryFromConfiguration:(ColumnTypesConfiguration *)configuration
{
	self.m_history = [NSMutableArray arrayWithArray: [configuration m_history]];	
}
-(void) addHistoryEntry: (enum HistoryEntryKind) kind
{
	[self addHistoryEntry: kind withDescription: @""];
}
-(void) addHistoryEntry:(enum HistoryEntryKind) kind withDescription:(NSString *)description
{
	[m_history addObject: [HistoryEntry entryWithKind: kind withDescription: description]];
}
@end

@implementation HistoryEntry

@synthesize m_kind;
@synthesize m_description;

-(id) initWithEntryKind: (enum HistoryEntryKind) kind withDescription: (NSString*) description
{
	if (self = [super init])
	{
		m_kind = kind;
        m_description = description;
	}
	return self;
}

+(id) entryWithKind: (enum HistoryEntryKind) kind withDescription: (NSString*) description
{
    return [[HistoryEntry alloc] initWithEntryKind: kind withDescription: description];
}

-(NSString*) toString
{
	NSMutableString* buffer = [NSMutableString stringWithString: [self operation]];
	[buffer appendFormat: @"\t%@", m_description ];
	return buffer;
}

-(NSString*) operation
{
	switch (m_kind) {
		case HDV_FILTER:
			return @"HDV: Filter";
		case HDV_RANK_COLUMNS:					
			return @"HDV: Rank product";
		case HDV_TRANSPOSE:
			return @"HDV: Transpose";
		case HDV_REMOVE_DUPLICATES:
			return @"HDV: Remove duplicate rows";
		case HDV_ID2FREQ:
			return @"HDV: Id2Frequency";
		case HDV_FREQ2ID:
			return @"HDV: Frequency2Id";
		case HDV_GENE_FINGERPRING_LIST_OF_GENES:
			return @"HDV: Gene fingerprint(list of genes)";
		case HDV_GENE_FINGERPRING_COUNT:
			return @"HDV: Gene fingerprint(count of genes)";
		case HDV_REORDER:
			return @"HDV: Reordering";
		case HDV_PERCENTILES:
			return @"HDV: Percentiles";
		case HDV_RESAMPLER_OUTPUT:
			return @"HDV: Resampler output";
		case HDV_RESAMPLER_SUMMARY:
			return @"HDV: Resampler summary";
		case HDV_SPECIAL_APPLY_FUNCTION:
			return @"HDV: Apply function";
		case HDV_SPECIAL_LARGEST_VALUE:
			return @"HDV: Largest value";
		case HDV_MERGE:
			return @"HDV: Merge";
		case HDV_BATCH_MERGE:
			return @"HDV: Batch merge";
		case HDV_WILDCARD_EXTRACT:
			return @"HDV: Wildcard extract";
		case HDV_CALC_FREQ_TABLE:
			return @"HDV: Calculate frequency table";
		case HDV_CALC_FREQ_TABLE_FOR_ALL_FILES_BY_COLUMN:
			return @"HDV: Calculate frequency table for all files";
		case HDV_EXTRACT:
			return @"HDV: Extract";
		case HDV_TRANSFORM:
			return @"HDV: Transform";
		case HDV_SEARCH:
			return @"HDV: Search";
		case HDV_ROW_COLUMN_STATISTIC:
			return @"HDV: Row & Column statistic";
        case HDV_SPLIT:
            return @"HDV: Split";
		default:
			return @"Unknow operation";
	}
}
-(NSString*) description
{
	return m_description;
}

@end

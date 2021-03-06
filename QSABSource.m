#import "QSObject_ContactHandling.h"
#import "ABPerson_Display.h"
#import "QSABSource.h"

static NSTimer *delayScan = nil;

@implementation QSAddressBookObjectSource
- (id)init {
	if ((self = [super init])) {
		contactDictionary = [[NSMutableDictionary alloc]init];
		addressBookModDate = [NSDate timeIntervalSinceReferenceDate];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addressBookChanged:) name:kABDatabaseChangedExternallyNotification object:nil];
	}
	return self;
}

- (BOOL)usesGlobalSettings {return YES;}

- (NSArray *)contactGroups {
	NSMutableArray *array = [NSMutableArray array];
	[array addObject:@"All Contacts"];
	
	ABAddressBook *book = [ABAddressBook addressBook];
	NSMutableArray *groups = [[[[book groups] valueForKey:kABGroupNameProperty] mutableCopy] autorelease];
	[groups removeObject:@"Me"];
	[groups sortUsingSelector:@selector(caseInsensitiveCompare:)];
	
	[array addObjectsFromArray:groups];
	return array;
}


- (NSArray *)contactDistributions {
	NSMutableArray *array = [NSMutableArray array];
	[array addObject:@"None"];
	
	ABAddressBook *book = [ABAddressBook addressBook];
	NSMutableArray *groups = [[[[book groups] valueForKey:kABGroupNameProperty] mutableCopy] autorelease];
	[groups removeObject:@"Me"];
	[groups sortUsingSelector:@selector(caseInsensitiveCompare:)];
	
	[array addObjectsFromArray:groups];
	return array;
}
// - (void)refreshGroupList {
//	[groupList removeAllItems];
//	[distributionList removeAllItems];
//	
//
//	NSLog(@"group %@", groups);
//	[groupList addItemWithTitle:@"All Contacts"];
//	[[groupList menu]addItem:[NSMenuItem separatorItem]];
//	[groupList addItemsWithTitles:groups];
//	
//	[distributionList addItemWithTitle:@"Default Emails"];
//	[[distributionList menu]addItem:[NSMenuItem separatorItem]];
//	[distributionList addItemsWithTitles:groups];
//}

- (NSImage *)iconForEntry:(NSDictionary *)theEntry {return [[NSWorkspace sharedWorkspace]iconForFile:@"/Applications/Contacts.app"];}

- (NSArray *)contactWebPages {
	NSMutableArray *array = [NSMutableArray array];
	
	ABAddressBook *book = [ABAddressBook addressBook];
	NSArray *people = [book people];
	NSEnumerator *personEnumerator = [people objectEnumerator];
	id thePerson;
	while ((thePerson = [personEnumerator nextObject])) {
		NSString *homePage = [thePerson valueForProperty:kABHomePageProperty];
		if (!homePage)continue;
		
		NSString *name = NSLocalizedStringFromTableInBundle(@"(no name)", nil, [NSBundle bundleForClass:[self class]], nil);
		NSString *namePiece;
		
		BOOL showAsCompany = [[thePerson valueForProperty:kABPersonFlags] integerValue] & kABShowAsMask & kABShowAsCompany;
		if (showAsCompany) {
			if ((namePiece = [thePerson valueForProperty:kABOrganizationProperty]))
				name = namePiece;
		}else {
			NSMutableArray *nameArray = [NSMutableArray arrayWithCapacity:3];
			if ((namePiece = [thePerson valueForProperty:kABFirstNameProperty]))
				[nameArray addObject:namePiece];
			if ((namePiece = [thePerson valueForProperty:kABMiddleNameProperty]))
				[nameArray addObject:namePiece];
			if ((namePiece = [thePerson valueForProperty:kABLastNameProperty]))
				[nameArray addObject:namePiece];
			if ([nameArray count])name = [nameArray componentsJoinedByString:@" "];
		}
		QSObject *object = [QSObject URLObjectWithURL:homePage
                                          title:name];
		if (object) {
            [array addObject:object];
        }
	}
	NSSortDescriptor *nameDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"displayName" ascending:YES] autorelease];
  [array sortUsingDescriptors:[NSArray arrayWithObject:nameDescriptor]];
	
	return array;
}
- (void) addressBookChanged:(NSNotification *)notif {
	[self invalidateSelf];
}

- (BOOL)indexIsValidFromDate:(NSDate *)indexDate forEntry:(NSDictionary *)theEntry {
	return ([indexDate timeIntervalSinceReferenceDate] > addressBookModDate);
}

- (void)invalidateSelf {
	addressBookModDate = [NSDate timeIntervalSinceReferenceDate];
    // cancel previously scheduled scan
    [delayScan invalidate];
    // wait 10 seconds (for repeated notifications) before scanning
    delayScan = [NSTimer scheduledTimerWithTimeInterval:10 target:[super self] selector:@selector(invalidateSelf) userInfo:nil repeats:NO];
}

- (BOOL)objectHasValidChildren:(QSObject *)object
{
    return YES;
}

- (BOOL)loadChildrenForObject:(QSObject *)object {
    NSArray *abchildren = [QSLib scoredArrayForType:QSABPersonType];
    if (![abchildren count]) {
        abchildren = [self objectsForEntry:nil];
    }
    // sort contacts by last name
    abchildren = [abchildren sortedArrayUsingComparator:^NSComparisonResult(QSObject *person1, QSObject *person2) {
        return [[person1 objectForMeta:@"surname"] caseInsensitiveCompare:[person2 objectForMeta:@"surname"]];
    }];
    [object setChildren:abchildren];
    return YES;
}

- (NSArray *)objectsForEntry:(NSDictionary *)theEntry {
    NSMutableArray *array = [NSMutableArray array];

    ABAddressBook *book = [ABAddressBook addressBook];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    BOOL includePhone = [defaults boolForKey:@"QSABIncludePhone"];
    BOOL includeURL = [defaults boolForKey:@"QSABIncludeURL"];
    BOOL includeIM = [defaults boolForKey:@"QSABIncludeIM"];
    BOOL includeEmail = [defaults boolForKey:@"QSABIncludeEmail"];
    BOOL includeContacts = [defaults boolForKey:@"QSABIncludeContacts"];
    
    NSArray *people = [book people];
    if (!includeContacts) {
        return array;
    }

    if ([NSApplication isMountainLion]) {
        NSMutableArray *addedPeople = [NSMutableArray array];
        for (id thePerson in people) {
            if ([addedPeople containsObject:thePerson]) {
                continue;
            }
            NSArray *linkedPeople = [thePerson linkedPeople];
            ABPerson *localPerson = nil;
            if ([linkedPeople count] > 1) {
                [addedPeople addObjectsFromArray:linkedPeople];
                // linked people exist for this contact, use the 'local' contact (if it exists) as the basis
                NSIndexSet *ind = [linkedPeople indexesOfObjectsWithOptions:NSEnumerationConcurrent passingTest:^BOOL(ABPerson *p, NSUInteger idx, BOOL *stop) {
                    return [p valueForProperty:kABSocialProfileProperty] == nil;
                }];
                if ([ind count]) {
                    localPerson = [linkedPeople objectAtIndex:[ind lastIndex]];
                } else {
                    localPerson = [linkedPeople objectAtIndex:0];
                }
            } else {
                localPerson = thePerson;
            }
            


            if (includeContacts)	[array addObject:[QSObject objectWithPerson:localPerson]];
        }
    } else {
        for(id thePerson in people) {
            if (includeContacts)	[array addObject:[QSObject objectWithPerson:thePerson]];
            if (includePhone)		[array addObjectsFromArray:[QSContactObjectHandler phoneObjectsForPerson:thePerson asChild:NO]];
            if (includeURL)			[array addObjectsFromArray:[QSContactObjectHandler URLObjectsForPerson:thePerson asChild:NO]];
            if (includeIM)			[array addObjectsFromArray:[QSContactObjectHandler imObjectsForPerson:thePerson asChild:NO]];
            if (includeEmail)		[array addObjectsFromArray:[QSContactObjectHandler emailObjectsForPerson:thePerson asChild:NO]];
        }
    }
    return array;
}

@end

# define kContactShowAction @"QSABContactShowAction"
# define kContactEditAction @"QSABContactEditAction"

@implementation QSABContactActions

// - (NSArray *)actions {
//	
//	NSMutableArray *actionArray = [NSMutableArray arrayWithCapacity:5];
//	//NSString *chatApp = [[NSWorkspace sharedWorkspace]absolutePathForAppBundleWithIdentifier:[QSReg chatMediatorID]];
//	
//	//NSImage *chatIcon = [[NSWorkspace sharedWorkspace]iconForFile:chatApp];
//	   
//	//  NSImage *finderProxyIcon = [[(QSController *)[NSApp delegate]finderProxy]icon];  
//	
//	QSAction *action;
//	
//	action = [QSAction actionWithIdentifier:kContactShowAction];
//	[action setIcon:        [QSResourceManager imageNamed:@"com.apple.AddressBook"]];
//	[action setProvider:    self];
//	[action setArgumentCount:1];
//	[actionArray addObject:action];  
//	
//	action = [QSAction actionWithIdentifier:kContactEditAction];
//	[action setIcon:        [QSResourceManager imageNamed:@"com.apple.AddressBook"]];
//	[action setProvider:    self];
//	[action setArgumentCount:1];
//	[actionArray addObject:action];  
//	
//	
//	
//	return actionArray; 	
//}

/*
 - (NSArray *)validActionsForDirectObject:(QSObject *)dObject indirectObject:(QSObject *)iObject {
   NSMutableArray *newActions = [NSMutableArray arrayWithCapacity:1];
   if ([[dObject primaryType] isEqualToString:@"ABPeopleUIDsPboardType"]) {
     ABPerson *person = (ABPerson *)[[ABAddressBook sharedAddressBook] recordForUniqueId:[dObject identifier]];
     
     [newActions addObject:kContactShowAction];
     [newActions addObject:kContactEditAction];
     
     
     if (0 && [(NSArray *)[person valueForProperty:kABAIMInstantProperty]count]) {
       [newActions addObject:kContactIMAction];  
       // ***warning   * learn to check if they are online
       [newActions addObject:kContactSendItemIMAction];
       
       //  Person *thisPerson = [[[AddressCard alloc]initWithABPerson:person]autorelease];
       //  [IMService connectToDaemonWithLaunch:NO];
       
     }
     // [AddressBookPeople loadBuddyList];
     
     // People *people = [[[People alloc]init]autorelease];
     //[people addPerson:thisPerson];
     //NSLog(@"%@", );
     //  [People sendMessageToPeople:[NSArray arrayWithObject:thisPerson]];
     // [self defaultEmailAddress];
   }else if ([dObject objectForType:QSTextType]) {
     [newActions addObject:kItemSendToContactIMAction];
   }
   
   return newActions;
 }
 
 
 - (NSArray *)validIndirectObjectsForAction:(NSString *)action directObject:(QSObject *)dObject {
   //  NSLog(@"request");
   if ([action isEqualToString:kContactSendItemEmailAction]) {
     return nil; //[QSLibarrayForType:NSFilenamesPboardType];
   }
   if ([action isEqualToString:kContactSendItemIMAction]) {
     
     QSObject *textObject = [QSObject textProxyObjectWithDefaultValue:@""];
     return [NSArray arrayWithObject:textObject]; //[QSLibarrayForType:NSFilenamesPboardType];
                                                  //   return [NSArray arrayWithObject:QSTextProxy]; //[QSLibarrayForType:NSFilenamesPboardType];
   }
   if ([action isEqualToString:kItemSendToContactEmailAction]) {
     QSLibrarian *librarian = QSLib;
     return [librarian scoredArrayForString:nil inSet:[librarian arrayForType:@"ABPeopleUIDsPboardType"]];
     return [[librarian arrayForType:@"ABPeopleUIDsPboardType"] sortedArrayUsingSelector:@selector(nameCompare:)];
   }
   return nil;
 }
 
 - (QSObject *)performAction:(QSAction *)action directObject:(QSBasicObject *)dObject indirectObject:(QSBasicObject *)iObject {
   //NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
   if ([[action identifier] isEqualToString:kContactShowAction]) {
			} else if ([[action identifier] isEqualToString:kContactEditAction]) {
      }
   else if ([[action identifier] isEqualToString:kContactEmailAction]) {
     ABPerson *person = (ABPerson *)[[ABAddressBook sharedAddressBook] recordForUniqueId:[dObject identifier]];
     NSString *address = [[person valueForProperty:kABEmailProperty]valueAtIndex:0];
     [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"mailto:%@", address]]];
   }
   return nil;
 }
 
 */

- (QSObject *)showContact:(QSObject *)dObject {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"addressbook://%@", [dObject identifier]]]];
	return nil;
}

- (QSObject *)editContact:(QSObject *)dObject {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"addressbook://%@?edit", [dObject identifier]]]];
	return nil;
}


- (QSObject *)sendItemViaIM:(QSObject *)dObject toPerson:(QSObject *)iObject {
	if ([dObject validPaths]) {
		[[QSReg preferredChatMediator] sendFile:[dObject stringValue] toPerson:[iObject identifier]];
	}else {
		[[QSReg preferredChatMediator] sendText:[dObject stringValue] toPerson:[iObject identifier]];
	}	
	return nil;
}

- (QSObject *)composeIMToPerson:(QSObject *)dObject {
	[[QSReg preferredChatMediator] chatWithPerson:[dObject identifier]];
	return nil;
}


@end

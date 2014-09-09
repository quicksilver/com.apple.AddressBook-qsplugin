#import <AddressBook/AddressBook.h>
#import "QSObject_ContactHandling.h"
#import "ABPerson_Display.h"

@implementation QSContactObjectHandler
// Object Handler Methods
- (BOOL)objectHasChildren:(id <QSObject > )object {
    return YES;
}

- (void)setQuickIconForObject:(QSObject *)object {
    [object setIcon:[QSResourceManager imageNamed:@"VCard"]];
}

- (BOOL)loadIconForObject:(QSObject *)object {
	ABPerson *person = [object ABPerson];
	NSImage *personImage = [[NSImage alloc] initWithData:[person imageData]];
    if (!personImage && [NSApplication isMountainLion]) {
        // ML and above: if no icon exists, attempt to get one from a linked person (i.e. another source - Fb, Skype etc.)
        for (ABPerson *eachLinkedPerson in [person linkedPeople]) {
            if (eachLinkedPerson != person) {
                personImage = [[NSImage alloc] initWithData:[eachLinkedPerson imageData]];
                if (personImage) {
                    break;
                }
            }
        }
    }
	if (personImage) {
		[object setIcon:personImage];
		[personImage release];
	}
	return YES;
}

//- (NSString *)identifierForObject:(id <QSObject > )object {
//    return [[object objectForType:QSABPersonType] objectAtIndex:0];
//}

- (NSString *)identifierForObject:(id <QSObject > )object {
    return [[(QSObject *)object objectForType:@"ABPeopleUIDsPboardType"] objectAtIndex:0];
}

+ (NSString *)contactlingNameForPerson:(ABPerson *)person label:(NSString *)label type:(NSString *)type asChild:(BOOL)child {
    if (![label length]) {
        // label has no length, so the details have most likely come from an IM service, attenpt to use the IMService name as the label
        ABMultiValue *imDeets = [person valueForProperty:kABInstantMessageProperty];
        if (imDeets) {
            label = [[imDeets valueAtIndex:[imDeets indexForIdentifier:[imDeets primaryIdentifier]]] objectForKey:kABInstantMessageServiceKey];
        }
    }
    label = ABLocalizedPropertyOrLabel(label);
    if ([type length]) {
        type = ABLocalizedPropertyOrLabel(type);
    }
	if (child)
		return [[NSString stringWithFormat:@"%@%@", label, [type length] ? [NSString stringWithFormat:@" %@",type] : @""] capitalizedString];
	else
		return [NSString stringWithFormat:@"%@'s %@%@", [person displayName], label, [type length] ? [NSString stringWithFormat:@" %@",type] : @""];
}

+ (NSArray *)URLObjectsForPerson:(ABPerson *)person asChild:(BOOL)asChild {
    NSMutableArray *contactlings = [NSMutableArray arrayWithCapacity:1];
    NSArray *peeps = nil;
    if ([NSApplication isMountainLion]) {
        peeps = [person linkedPeople];
    } else {
        peeps = [NSArray arrayWithObject:person];
    }
    NSMutableArray *usedURLs = [NSMutableArray array];
    for (ABPerson *thePerson in peeps) {
        ABMultiValue *urls = [thePerson valueForProperty:kABURLsProperty];
        NSUInteger i;
        for (i = 0; i < [urls count]; i++) {
            NSString *url = [urls valueAtIndex:i];
            if ([usedURLs containsObject:url]) {
                continue;
            }
            [usedURLs addObject:url];
            NSString *name = [self contactlingNameForPerson:thePerson label:[urls labelAtIndex:i] type:kABURLsProperty asChild:asChild];
            
            QSObject *obj = [QSObject URLObjectWithURL:url title:name];
            if (obj) {
                [obj setParentID:[person uniqueId]];
                [contactlings addObject:obj];
            }
        }
    }
	return contactlings;
}

+ (NSArray *)emailObjectsForPerson:(ABPerson *)person asChild:(BOOL)asChild {
    NSMutableArray *contactlings = [NSMutableArray arrayWithCapacity:1];

	NSUInteger i;
    NSArray *peeps = nil;
    if ([NSApplication isMountainLion]) {
        peeps = [person linkedPeople];
    } else {
        peeps = [NSArray arrayWithObject:person];
    }
    NSMutableArray *usedEmails = [NSMutableArray array];
    
    for (ABPerson *thePerson in peeps) {
        ABMultiValue *emailAddresses = [thePerson valueForProperty:kABEmailProperty];
        for (i = 0; i < [emailAddresses count]; i++) {
            NSString *address = [emailAddresses valueAtIndex:i];
            if ([usedEmails containsObject:address]) {
                continue;
            }
            [usedEmails addObject:address];
            NSString *name = [self contactlingNameForPerson:thePerson label:[emailAddresses labelAtIndex:i] type:kABEmailProperty asChild:asChild];
            
            QSObject *obj = [QSObject URLObjectWithURL:[NSString stringWithFormat:@"mailto:%@", address]
                                                 title:name];
            [obj setLabel:address];
            [obj setDetails:name];
            if (obj) {
                [obj setParentID:[person uniqueId]];
                [contactlings addObject:obj];
            }
        }
    }

	return contactlings;
}

+ (NSArray *)phoneObjectsForPerson:(ABPerson *)person asChild:(BOOL)asChild {
    NSMutableArray *contactlings = [NSMutableArray arrayWithCapacity:1];
    
    NSMutableArray *usedPhoneNos = [NSMutableArray array];
    NSArray *peeps = nil;
    if ([NSApplication isMountainLion]) {
        peeps = [person linkedPeople];
    } else {
        peeps = [NSArray arrayWithObject:person];
    }
    
    for (ABPerson *thePerson in peeps) {
        ABMultiValue *phoneNumbers = [thePerson valueForProperty:kABPhoneProperty];
        NSUInteger i;
        for (i = 0; i < [phoneNumbers count]; i++) {
            NSString *phoneNo = [phoneNumbers valueAtIndex:i];
            if ([usedPhoneNos containsObject:phoneNo]) {
                continue;
            }
            [usedPhoneNos addObject:phoneNo];
            NSString *name = [self contactlingNameForPerson:thePerson label:[phoneNumbers labelAtIndex:i] type:kABPhoneProperty asChild:asChild];
            QSObject *obj = [QSObject objectWithContactDetail:phoneNo name:name type:QSContactPhoneType];
            
            if (obj) {
                [obj setParentID:[person uniqueId]];
                [contactlings addObject:obj];
            }
        }
    }


	return contactlings;
}


+ (NSArray *)addressObjectsForPerson:(ABPerson *)person asChild:(BOOL)asChild {
	NSMutableArray *contactlings = [NSMutableArray arrayWithCapacity:1];
	NSUInteger i;
    NSMutableArray *usedAddresses = [NSMutableArray array];

    NSArray *peeps = nil;
    if ([NSApplication isMountainLion]) {
        peeps = [person linkedPeople];
    } else {
        peeps = [NSArray arrayWithObject:person];
    }
    
    for (ABPerson *thePerson in peeps) {
        ABMultiValue *addresses = [thePerson valueForProperty:kABAddressProperty];
        for (i = 0; i < [addresses count]; i++) {
            ABMultiValue *address = [addresses valueAtIndex:i];
            NSString *string = [[[ABAddressBook sharedAddressBook] formattedAddressFromDictionary:(NSDictionary *)address] string];
            if ([usedAddresses containsObject:string]) {
                continue;
            }
            [usedAddresses addObject:string];
            NSString *name = [self contactlingNameForPerson:thePerson label:[addresses labelAtIndex:i] type:kABAddressProperty asChild:asChild];
            
            
            QSObject * obj = [QSObject objectWithContactDetail:string name:name type:QSContactAddressType];
            
            if (obj) {
                [obj setParentID:[person uniqueId]];
                [contactlings addObject:obj];
            }
        }
    }
	return contactlings;
}

+ (NSArray *)imObjectsForPerson:(ABPerson *)person asChild:(BOOL)asChild {
    NSMutableSet *contactlings = [NSMutableArray arrayWithCapacity:1];
    NSUInteger i;
    NSMutableArray *usernames = [NSMutableArray array];
    NSArray *peeps = nil;
    if ([NSApplication isMountainLion]) {
        peeps = [person linkedPeople];
    } else {
        peeps = [NSArray arrayWithObject:person];
    }

    for (ABPerson *thePerson in peeps) {
        ABMultiValue *ims = [person valueForProperty:kABInstantMessageProperty];
        for (i = 0; i < [ims count]; i++) {
            NSString *username = [[ims valueAtIndex:i] objectForKey:kABInstantMessageUsernameKey];
            if ([usernames containsObject:username]) {
                continue;
            }
            [usernames addObject:username];
            NSString *name = [self contactlingNameForPerson:person label:[ims labelAtIndex:i] type:@""  asChild:asChild];
            QSObject *obj = [QSObject objectWithContactDetail:username name:name type:QSIMAccountType];
            
            if (obj) {
                [obj setParentID:[person uniqueId]];
                [contactlings addObject:obj];
            }
        }
    }

	return [contactlings allObjects];
}

- (BOOL)loadChildrenForObject:(QSObject *)object {
    ABPerson *person = [object ABPerson];
    
    NSMutableArray *contactlings = [NSMutableArray arrayWithCapacity:1];
    
	[contactlings addObjectsFromArray:[QSContactObjectHandler phoneObjectsForPerson:person asChild:YES]];
	[contactlings addObjectsFromArray:[QSContactObjectHandler emailObjectsForPerson:person asChild:YES]];
	[contactlings addObjectsFromArray:[QSContactObjectHandler imObjectsForPerson:person asChild:YES]];
	[contactlings addObjectsFromArray:[QSContactObjectHandler addressObjectsForPerson:person asChild:YES]];
	[contactlings addObjectsFromArray:[QSContactObjectHandler URLObjectsForPerson:person asChild:YES]];
	
	NSString *note = [person valueForProperty:kABNoteProperty];
    if (note && [note length]) {
        QSObject *obj = [QSObject objectWithString:note];
        if (obj) {
            [obj setParentID:[object identifier]];
            [contactlings addObject:obj];
        }
    }
	
    [contactlings makeObjectsPerformSelector:@selector(setParentID:) withObject:[object identifier]];
    
    if (contactlings) {
        [object setChildren:contactlings];
        return YES;
    }
    return NO;
}

@end


@implementation QSObject (ContactHandling)

#pragma mark QSObject creation methods

- (QSObject *)initWithPerson:(ABPerson *)person {
	//id object = [QSObject objectWithIdentifier:[person uniqueId]];
    if ((self = [self init])) {
        [data setObject:[person uniqueId] forKey:QSABPersonType];
		//[QSObject registerObject:self withIdentifier:[self identifier]];
        [self setIdentifier:[person uniqueId]];
		[self loadContactInfo:person];
    }
    return self;
}

+ (QSObject *)objectWithPerson:(ABPerson *)person {
    return [[[QSObject alloc] initWithPerson:person] autorelease];
}

+ (QSObject *)objectWithContactDetail:(NSString *)detail name:(NSString *)name type:(NSString *)type {
    
    QSObject * obj = [QSObject objectWithString:detail name:name type:QSContactPhoneType];
    [obj setDetails:name];
    [obj setLabel:detail];
    return obj;
    
}
// - -NSString *formalName(NSString *title, NSString *firstName, NSString *middleName, NSString *lastName, NSString *suffix) {
//NSMutableString *formalName=

- (ABPerson *)ABPerson
{
    return (ABPerson *)[[ABAddressBook sharedAddressBook] recordForUniqueId:[self identifier]];
}

- (void)loadContactInfo {
    [self loadContactInfo:nil];
}

- (void)loadContactInfo:(ABPerson *)person {
    if (person == nil) {
        person = [self ABPerson];
    }
	
	NSString *newName = nil;
	NSString *newLabel = nil;
	
	NSString *firstName = [person valueForProperty:kABFirstNameProperty];
	NSString *lastName = [person valueForProperty:kABLastNameProperty];
	NSString *middleName = [person valueForProperty:kABMiddleNameProperty];
//	NSString *nickName = [person valueForProperty:kABNicknameProperty];
  
	NSString *title = [person valueForProperty:kABTitleProperty];
	NSString *suffix = [person valueForProperty:kABSuffixProperty];
    NSString *jobTitle = [person valueForProperty:kABJobTitleProperty];
    NSString *companyName = [person valueForProperty:kABOrganizationProperty];

	newLabel = formattedContactName(firstName, lastName, middleName, title, suffix);
	newName = [person displayName];
	
	[self setName:newName];
    [self setObject:lastName forMeta:@"surname"];
	
	if (newLabel)
		[self setLabel:newLabel];
	
	[self setPrimaryType:QSABPersonType];
	
	ABMultiValue *emailAddresses = [person valueForProperty:kABEmailProperty];
	NSString *address = [emailAddresses valueAtIndex:0];

	if (address) {
		[self setObject:address forType:QSEmailAddressType];
    }
	
    NSMutableArray *detailsParts = [[NSMutableArray alloc] init];
    if (jobTitle) {
        [detailsParts addObject:jobTitle];
    }
    if (companyName) {
        [detailsParts addObject:companyName];
    }
    if ([detailsParts count]) {
        // show title, company, or "title, company" if both are present
        [self setDetails:[detailsParts componentsJoinedByString:@", "]];
    } else {
        // prevent details from showing at all by setting them equal to name
        [self setDetails:[self displayName]];
    }
    [detailsParts release];
	/*	NSArray *aimAccounts = [person valueForProperty:kABAIMInstantProperty];
	if ([aimAccounts count])
		[self setObject:[NSString stringWithFormat:@"AIM:%@", [aimAccounts valueAtIndex:0]] forType:QSIMAccountType]; */
	[self useDefaultIMFromPerson:person];
}

- (BOOL)useDefaultEmailFromPerson:(ABPerson *)person {
	return NO;
}

/*!
* @abstract If possible, makes this object respond to IM actions by associating it with the first IM account it finds.
 * @param person The person to search for IM accounts.
 * @result YES if a suitable IM account was found, NO otherwise.
 */
- (BOOL)useDefaultIMFromPerson:(ABPerson *)person {
	ABMultiValue *im = [person valueForProperty:kABInstantMessageProperty];
    // [ABMultiValue propertyType] == kABMultiDictionaryProperty (= kABMultiValueMask | kABDictionaryProperty)
    if (!im) {
        return NO;
    }
    NSDictionary *primaryIM = [im valueAtIndex:[im indexForIdentifier:[im primaryIdentifier]]];
    NSString *primaryIMType = [primaryIM objectForKey:kABInstantMessageServiceKey];
    if (!primaryIMType) {
        return NO;
    }
    static NSDictionary *imProperties = nil;
    if (imProperties == nil) {
        imProperties = [[NSDictionary alloc] initWithObjectsAndKeys:@"AIM:", kABInstantMessageServiceAIM, @"MSN:", kABInstantMessageServiceMSN, @"Yahoo!:", kABInstantMessageServiceYahoo, @"ICQ:", kABInstantMessageServiceICQ, @"Jabber:", kABInstantMessageServiceJabber, @"Facebook:", kABInstantMessageServiceFacebook, @"Google Talk:", kABInstantMessageServiceGoogleTalk, @"Gadu Gadu:", kABInstantMessageServiceGaduGadu, @"QQ:", kABInstantMessageServiceQQ, @"Skype:", kABInstantMessageServiceSkype, nil];
    }
    NSString *prefix = [imProperties objectForKey:primaryIMType];
    if (!prefix) {
        return NO;
    }
	[self setObject:[prefix stringByAppendingString:[primaryIM objectForKey:kABInstantMessageUsernameKey]] forType:QSIMAccountType];
    return YES;
}


@end

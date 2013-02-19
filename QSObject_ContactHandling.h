

NSString *formattedContactName(NSString *firstName, NSString *lastName, NSString *middleName, NSString *suffix, NSString *prefix);

@interface QSContactObjectHandler : NSObject
+ (NSArray *)URLObjectsForPerson:(ABPerson *)person asChild:(BOOL)asChild;
+ (NSArray *)emailObjectsForPerson:(ABPerson *)person asChild:(BOOL)asChild;
+ (NSArray *)phoneObjectsForPerson:(ABPerson *)person asChild:(BOOL)asChild;
+ (NSArray *)addressObjectsForPerson:(ABPerson *)person asChild:(BOOL)asChild;
+ (NSArray *)imObjectsForPerson:(ABPerson *)person asChild:(BOOL)asChild;
- (BOOL)loadChildrenForObject:(QSObject *)object;
@end

@interface QSObject (ContactHandling)
+ (id)objectWithPerson:(ABPerson *)person;
//+ (id)objectWithString:(NSString *)string name:(NSString *)aName type:(NSString *)aType;
//- (id)initWithString:(NSString *)string name:(NSString *)aName type:(NSString *)aType;
- (ABPerson *)ABPerson;
- (id)initWithPerson:(ABPerson *)person;
- (void)loadContactInfo;
- (void)loadContactInfo:(ABPerson *)person;

- (BOOL)useDefaultIMFromPerson:(ABPerson *)person;
- (BOOL)useDefaultEmailFromPerson:(ABPerson *)person;
@end
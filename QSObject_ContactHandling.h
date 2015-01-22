@class ABPerson;

@interface QSContactObjectHandler : NSObject
+ (NSArray *)URLObjectsForPerson:(ABPerson *)person asChild:(BOOL)asChild;
+ (NSArray *)emailObjectsForPerson:(ABPerson *)person asChild:(BOOL)asChild;
+ (NSArray *)phoneObjectsForPerson:(ABPerson *)person asChild:(BOOL)asChild;
+ (NSArray *)addressObjectsForPerson:(ABPerson *)person asChild:(BOOL)asChild;
+ (NSArray *)imObjectsForPerson:(ABPerson *)person asChild:(BOOL)asChild;
- (BOOL)loadChildrenForObject:(QSObject *)object;
@end

@interface QSObject (ContactHandling)

- (QSObject *)initWithPerson:(ABPerson *)person;
+ (QSObject *)objectWithContactDetail:(NSString*)detail name:(NSString *)name type:(NSString *)type;
+ (QSObject *)objectWithPerson:(ABPerson *)person;

- (ABPerson *)ABPerson;
- (void)loadContactInfo;
- (void)loadContactInfo:(ABPerson *)person;

- (BOOL)useDefaultIMFromPerson:(ABPerson *)person;
- (BOOL)useDefaultEmailFromPerson:(ABPerson *)person;
@end
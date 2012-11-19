@interface QSABContactActions : QSObjectSource
@end
@interface QSAddressBookObjectSource : QSObjectSource{
	NSTimeInterval addressBookModDate;
	NSMutableDictionary *contactDictionary;
	
	IBOutlet NSPopUpButton *groupList;
	IBOutlet NSPopUpButton *distributionList;
}
@end


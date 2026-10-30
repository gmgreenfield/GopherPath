#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, GopherItemType) {
    GopherItemTypeText,
    GopherItemTypeMenu,
    GopherItemTypeSearch,
    GopherItemTypeBinary,
    GopherItemTypeImage,
    GopherItemTypeInfo,
    GopherItemTypeUnknown
};

@interface GopherItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *selector;
@property (nonatomic, copy) NSString *host;
@property (nonatomic) NSInteger port;
@property (nonatomic) GopherItemType type;
@property (nonatomic, copy) NSString *typeGlyph;
+ (NSArray<GopherItem *> *)menuItemsFromData:(NSData *)data;
@end

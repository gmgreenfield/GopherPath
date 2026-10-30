#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, GopherItemType) {
    GopherItemTypeText,
    GopherItemTypeMenu,
    GopherItemTypeSearch,
    GopherItemTypeBinary,
    GopherItemTypeImage,
    GopherItemTypeWebLink,
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
@property (nonatomic, copy, nullable) NSString *externalURL;
+ (NSArray<GopherItem *> *)menuItemsFromData:(NSData *)data;
@end

NS_ASSUME_NONNULL_END

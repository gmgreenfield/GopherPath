#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GopherClient : NSObject
- (void)fetchHost:(NSString *)host port:(NSInteger)port selector:(NSString *)selector query:(nullable NSString *)query completion:(void (^ _Nonnull)(NSData * _Nullable data, NSError * _Nullable error))completion;
@end

NS_ASSUME_NONNULL_END

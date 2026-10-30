#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GopherRequestToken : NSObject
@property (nonatomic, readonly, getter=isCancelled) BOOL cancelled;
- (void)cancel;
@end

@interface GopherClient : NSObject
- (GopherRequestToken *)fetchHost:(NSString *)host port:(NSInteger)port selector:(NSString *)selector query:(nullable NSString *)query completion:(void (^ _Nonnull)(NSData * _Nullable data, NSError * _Nullable error))completion;
@end

NS_ASSUME_NONNULL_END

#import "GopherClient.h"
#import <netdb.h>
#import <sys/socket.h>
#import <sys/time.h>
#import <unistd.h>

static NSError *GopherSocketError(NSString *message) {
    return [NSError errorWithDomain:@"GUI Gopher" code:1 userInfo:@{NSLocalizedDescriptionKey: message}];
}

@interface GopherRequestToken ()
@property (nonatomic, strong) NSLock *lock;
@property (nonatomic, readwrite, getter=isCancelled) BOOL cancelled;
@property (nonatomic) int socketFD;
- (BOOL)installSocket:(int)socketFD;
- (void)closeSocket;
@end

@implementation GopherRequestToken

- (instancetype)init {
    self = [super init];
    if (self) { _lock = [[NSLock alloc] init]; _socketFD = -1; }
    return self;
}

- (BOOL)isCancelled {
    [self.lock lock];
    BOOL value = _cancelled;
    [self.lock unlock];
    return value;
}

- (BOOL)installSocket:(int)socketFD {
    [self.lock lock];
    BOOL accepted = !_cancelled;
    if (accepted) self.socketFD = socketFD;
    [self.lock unlock];
    if (!accepted) close(socketFD);
    return accepted;
}

- (void)closeSocket {
    [self.lock lock];
    int descriptor = self.socketFD;
    self.socketFD = -1;
    [self.lock unlock];
    if (descriptor >= 0) close(descriptor);
}

- (void)cancel {
    [self.lock lock];
    self.cancelled = YES;
    int descriptor = self.socketFD;
    self.socketFD = -1;
    [self.lock unlock];
    if (descriptor >= 0) close(descriptor);
}

@end

@implementation GopherClient

- (GopherRequestToken *)fetchHost:(NSString *)host port:(NSInteger)port selector:(NSString *)selector query:(NSString *)query completion:(void (^)(NSData *, NSError *))completion {
    GopherRequestToken *token = [[GopherRequestToken alloc] init];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        struct addrinfo hints = {0};
        hints.ai_family = AF_UNSPEC;
        hints.ai_socktype = SOCK_STREAM;
        struct addrinfo *addresses = NULL;
        NSString *service = [NSString stringWithFormat:@"%ld", (long)port];
        int lookup = getaddrinfo(host.UTF8String, service.UTF8String, &hints, &addresses);
        if (lookup != 0) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (!token.cancelled) completion(nil, GopherSocketError([NSString stringWithUTF8String:gai_strerror(lookup)])); });
            return;
        }

        int socketFD = -1;
        for (struct addrinfo *address = addresses; address && !token.cancelled; address = address->ai_next) {
            socketFD = socket(address->ai_family, address->ai_socktype, address->ai_protocol);
            if (socketFD < 0) continue;
            struct timeval timeout = {.tv_sec = 10, .tv_usec = 0};
            int noSigPipe = 1;
            setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
            setsockopt(socketFD, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
            setsockopt(socketFD, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, sizeof(noSigPipe));
            if (![token installSocket:socketFD]) { socketFD = -1; break; }
            if (connect(socketFD, address->ai_addr, address->ai_addrlen) == 0) break;
            [token closeSocket];
            socketFD = -1;
        }
        freeaddrinfo(addresses);
        if (token.cancelled) return;
        if (socketFD < 0) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (!token.cancelled) completion(nil, GopherSocketError(@"Could not connect to that Gopher server.")); });
            return;
        }

        NSString *request = [selector stringByReplacingOccurrencesOfString:@"\r" withString:@""];
        request = [request stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        if (query.length) request = [request stringByAppendingFormat:@"\t%@", [[query stringByReplacingOccurrencesOfString:@"\r" withString:@""] stringByReplacingOccurrencesOfString:@"\n" withString:@""]];
        NSData *requestData = [[request stringByAppendingString:@"\r\n"] dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:YES];
        const uint8_t *bytes = requestData.bytes;
        NSUInteger sent = 0;
        while (sent < requestData.length && !token.cancelled) {
            ssize_t count = send(socketFD, bytes + sent, requestData.length - sent, 0);
            if (count <= 0) break;
            sent += (NSUInteger)count;
        }
        if (token.cancelled) { [token closeSocket]; return; }
        if (sent != requestData.length) {
            [token closeSocket];
            dispatch_async(dispatch_get_main_queue(), ^{ if (!token.cancelled) completion(nil, GopherSocketError(@"The request could not be sent.")); });
            return;
        }

        NSMutableData *response = [NSMutableData data];
        uint8_t buffer[8192];
        ssize_t count = 0;
        while (!token.cancelled && (count = recv(socketFD, buffer, sizeof(buffer), 0)) > 0) {
            [response appendBytes:buffer length:(NSUInteger)count];
            if (response.length > 32 * 1024 * 1024) break;
        }
        [token closeSocket];
        if (token.cancelled) return;
        if (response.length == 0 && count < 0) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (!token.cancelled) completion(nil, GopherSocketError(@"The server stopped responding.")); });
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{ if (!token.cancelled) completion(response, nil); });
    });
    return token;
}

@end

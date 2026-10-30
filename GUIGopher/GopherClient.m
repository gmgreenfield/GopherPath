#import "GopherClient.h"
#import <netdb.h>
#import <sys/socket.h>
#import <sys/time.h>
#import <unistd.h>

static NSError *GopherSocketError(NSString *message) {
    return [NSError errorWithDomain:@"GUI Gopher" code:1 userInfo:@{NSLocalizedDescriptionKey: message}];
}

@implementation GopherClient

- (void)fetchHost:(NSString *)host port:(NSInteger)port selector:(NSString *)selector query:(NSString *)query completion:(void (^)(NSData *, NSError *))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        struct addrinfo hints = {0};
        hints.ai_family = AF_UNSPEC;
        hints.ai_socktype = SOCK_STREAM;
        struct addrinfo *addresses = NULL;
        NSString *service = [NSString stringWithFormat:@"%ld", (long)port];
        int lookup = getaddrinfo(host.UTF8String, service.UTF8String, &hints, &addresses);
        if (lookup != 0) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, GopherSocketError([NSString stringWithUTF8String:gai_strerror(lookup)])); });
            return;
        }

        int socketFD = -1;
        for (struct addrinfo *address = addresses; address; address = address->ai_next) {
            socketFD = socket(address->ai_family, address->ai_socktype, address->ai_protocol);
            if (socketFD < 0) continue;
            struct timeval timeout = {.tv_sec = 10, .tv_usec = 0};
            setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
            setsockopt(socketFD, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
            if (connect(socketFD, address->ai_addr, address->ai_addrlen) == 0) break;
            close(socketFD);
            socketFD = -1;
        }
        freeaddrinfo(addresses);
        if (socketFD < 0) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, GopherSocketError(@"Could not connect to that Gopher server.")); });
            return;
        }

        NSString *request = [selector stringByReplacingOccurrencesOfString:@"\r" withString:@""];
        request = [request stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        if (query.length) request = [request stringByAppendingFormat:@"\t%@", [[query stringByReplacingOccurrencesOfString:@"\r" withString:@""] stringByReplacingOccurrencesOfString:@"\n" withString:@""]];
        NSData *requestData = [[request stringByAppendingString:@"\r\n"] dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:YES];
        const uint8_t *bytes = requestData.bytes;
        NSUInteger sent = 0;
        while (sent < requestData.length) {
            ssize_t count = send(socketFD, bytes + sent, requestData.length - sent, 0);
            if (count <= 0) break;
            sent += (NSUInteger)count;
        }
        if (sent != requestData.length) {
            close(socketFD);
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, GopherSocketError(@"The request could not be sent.")); });
            return;
        }

        NSMutableData *response = [NSMutableData data];
        uint8_t buffer[8192];
        ssize_t count = 0;
        while ((count = recv(socketFD, buffer, sizeof(buffer), 0)) > 0) {
            [response appendBytes:buffer length:(NSUInteger)count];
            if (response.length > 32 * 1024 * 1024) break;
        }
        close(socketFD);
        if (response.length == 0 && count < 0) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, GopherSocketError(@"The server stopped responding.")); });
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{ completion(response, nil); });
    });
}

@end

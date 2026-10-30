#import "GopherItem.h"

@implementation GopherItem

+ (NSArray<GopherItem *> *)menuItemsFromData:(NSData *)data {
    NSString *body = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    if (!body) body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSMutableArray<GopherItem *> *items = [NSMutableArray array];
    for (NSString *line in [body componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        if (line.length == 0 || [line isEqualToString:@"."]) continue;
        NSString *normalizedLine = [line hasPrefix:@".."] ? [line substringFromIndex:1] : line;
        NSArray<NSString *> *fields = [normalizedLine componentsSeparatedByString:@"\t"];
        if (fields.count < 4 || fields[0].length == 0) continue;

        unichar code = [fields[0] characterAtIndex:0];
        GopherItem *item = [[GopherItem alloc] init];
        item.title = fields[0].length > 1 ? [fields[0] substringFromIndex:1] : @"Untitled";
        item.selector = fields[1];
        item.host = fields[2];
        item.port = fields.count > 3 ? fields[3].integerValue : 70;
        if (item.port < 1 || item.port > 65535) item.port = 70;
        if (code == 'h') {
            for (NSUInteger index = 1; index < fields.count; index++) {
                NSString *field = [fields[index] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                NSRange marker = [field rangeOfString:@"URL:" options:NSCaseInsensitiveSearch];
                NSString *candidate = marker.location != NSNotFound ? [field substringFromIndex:NSMaxRange(marker)] : field;
                if (marker.location != NSNotFound || [candidate.lowercaseString hasPrefix:@"http://"] || [candidate.lowercaseString hasPrefix:@"https://"] || [candidate.lowercaseString hasPrefix:@"gopher://"]) {
                    candidate = [[candidate componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] firstObject];
                    NSURLComponents *components = [NSURLComponents componentsWithString:candidate];
                    NSString *scheme = components.scheme.lowercaseString;
                    if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"] || [scheme isEqualToString:@"gopher"]) item.externalURL = components.URL.absoluteString;
                    if (item.externalURL.length) break;
                }
            }
            if (item.externalURL.length) { item.type = GopherItemTypeWebLink; item.typeGlyph = @"arrow.up.right.square"; }
        }
        switch (code) {
            case '0': item.type = GopherItemTypeText; item.typeGlyph = @"doc.text"; break;
            case '1': item.type = GopherItemTypeMenu; item.typeGlyph = @"folder"; break;
            case '7': item.type = GopherItemTypeSearch; item.typeGlyph = @"magnifyingglass"; break;
            case '9': item.type = GopherItemTypeBinary; item.typeGlyph = @"arrow.down.doc"; break;
            case 'g': case 'I': item.type = GopherItemTypeImage; item.typeGlyph = @"photo"; break;
            case 'i': item.type = GopherItemTypeInfo; item.typeGlyph = @"text.alignleft"; break;
            default: if (item.type != GopherItemTypeWebLink) { item.type = GopherItemTypeUnknown; item.typeGlyph = @"link"; } break;
        }
        [items addObject:item];
    }
    return items;
}

@end

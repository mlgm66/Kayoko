#import "KayokoFilterApplicationBridge.h"
#import "KayokoFilterCatalog.h"
#import <notify.h>

static NSString *const kKayokoApplicationBridgeErrorDomain = @"com.mlgm.kayoko.app-catalog";

static NSDictionary *KayokoReadApplicationMessage(NSString *path) {
    NSData *data = [NSData dataWithContentsOfFile:path];
    id message = data ? [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable
        format:NULL error:nil] : nil;
    return [message isKindOfClass:[NSDictionary class]] ? message : nil;
}

static BOOL KayokoWriteApplicationMessage(NSDictionary *message, NSString *path, NSError **error) {
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:message format:NSPropertyListBinaryFormat_v1_0
        options:0 error:error];
    return data && [data writeToFile:path options:NSDataWritingAtomic error:error];
}

static NSError *KayokoApplicationBridgeError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:kKayokoApplicationBridgeErrorDomain code:code
        userInfo:@{NSLocalizedDescriptionKey : message}];
}

@interface KayokoFilterApplicationBridge ()
@property(nonatomic, copy) NSString *directoryPath;
@property(nonatomic, copy) NSString *requestPath;
@property(nonatomic, copy) NSString *responsePath;
@property(nonatomic, copy) NSString *requestNotification;
@property(nonatomic, copy) NSString *responseNotification;
@property(nonatomic, strong) NSLock *requestLock;
@property(nonatomic, assign) int serverToken;
@end

@implementation KayokoFilterApplicationBridge

+ (instancetype)sharedBridge {
    static KayokoFilterApplicationBridge *bridge;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *directory = [[KayokoHistoryDatabasePath() stringByDeletingLastPathComponent]
            stringByAppendingPathComponent:@"application-catalog"];
        bridge = [[self alloc] initWithDirectoryPath:directory notificationName:kKayokoApplicationBridgeErrorDomain];
    });
    return bridge;
}

- (instancetype)initWithDirectoryPath:(NSString *)path notificationName:(NSString *)name {
    self = [super init];
    if (self) {
        _directoryPath = [path copy];
        _requestPath = [path stringByAppendingPathComponent:@"request.plist"];
        _responsePath = [path stringByAppendingPathComponent:@"response.plist"];
        _requestNotification = [name stringByAppendingString:@".request"];
        _responseNotification = [name stringByAppendingString:@".response"];
        _requestLock = [[NSLock alloc] init];
        _serverToken = -1;
    }
    return self;
}

- (void)dealloc {
    [self stopServing];
}

- (BOOL)startServingWithProvider:(KayokoFilterApplicationProvider)provider {
    if ([self serverToken] != -1) {
        return YES;
    }
    __weak typeof(self) weakSelf = self;
    int token;
    uint32_t status = notify_register_dispatch([[self requestNotification] UTF8String], &token,
        dispatch_get_main_queue(), ^(int notificationToken) {
            (void)notificationToken;
            typeof(self) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            NSString *requestID = KayokoReadApplicationMessage([strongSelf requestPath])[@"requestID"];
            if (![requestID isKindOfClass:[NSString class]] || [requestID length] == 0) {
                return;
            }
            provider(^(NSArray<NSString *> *identifiers, NSError *error) {
                if (![KayokoReadApplicationMessage([strongSelf requestPath])[@"requestID"] isEqual:requestID]) {
                    return;
                }
                NSDictionary *response = error ? @{@"requestID" : requestID,
                    @"error" : @{ @"domain" : [error domain], @"code" : @([error code]),
                                  @"message" : [error localizedDescription] }} :
                    @{@"requestID" : requestID, @"identifiers" : identifiers ?: @[]};
                NSError *writeError = nil;
                if (KayokoWriteApplicationMessage(response, [strongSelf responsePath], &writeError)) {
                    notify_post([[strongSelf responseNotification] UTF8String]);
                } else {
                    NSLog(@"Kayoko application catalog response: %@", writeError);
                }
            });
        });
    if (status != NOTIFY_STATUS_OK) {
        return NO;
    }
    [self setServerToken:token];
    return YES;
}

- (void)stopServing {
    if ([self serverToken] != -1) {
        notify_cancel([self serverToken]);
        [self setServerToken:-1];
    }
}

// 在后台线程向 Core 请求当前应用来源，不另开历史数据库连接。
- (NSArray<NSString *> *)applicationIdentifiersWithError:(NSError **)error {
    [[self requestLock] lock];
    NSArray *identifiers;
    @try {
        identifiers = [self requestIdentifiersWithError:error];
    } @finally {
        [[self requestLock] unlock];
    }
    return identifiers;
}

- (NSArray<NSString *> *)requestIdentifiersWithError:(NSError **)error {
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSFileManager *files = [NSFileManager defaultManager];
    NSError *failure = nil;
    __block NSDictionary *response;
    NSArray *identifiers = nil;
    int token = -1;
    dispatch_semaphore_t received = dispatch_semaphore_create(0);
    do {
        if (![files createDirectoryAtPath:[self directoryPath] withIntermediateDirectories:YES attributes:nil error:&failure]) {
            break;
        }
        uint32_t status = notify_register_dispatch([[self responseNotification] UTF8String], &token,
            dispatch_queue_create("com.mlgm.kayoko.app-catalog.response", DISPATCH_QUEUE_SERIAL), ^(int notificationToken) {
                (void)notificationToken;
                NSDictionary *message = KayokoReadApplicationMessage([self responsePath]);
                if ([message[@"requestID"] isEqual:requestID]) {
                    response = message;
                    dispatch_semaphore_signal(received);
                }
            });
        if (status != NOTIFY_STATUS_OK) {
            token = -1;
            failure = KayokoApplicationBridgeError(status, @"Unable to register application catalog response");
            break;
        }
        if (!KayokoWriteApplicationMessage(@{@"requestID" : requestID}, [self requestPath], &failure)) {
            break;
        }
        status = notify_post([[self requestNotification] UTF8String]);
        if (status != NOTIFY_STATUS_OK) {
            failure = KayokoApplicationBridgeError(status, @"Unable to request application catalog");
            break;
        }
        if (dispatch_semaphore_wait(received, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) != 0) {
            failure = KayokoApplicationBridgeError(1, @"Application catalog request timed out");
            break;
        }
        NSDictionary *remoteError = response[@"error"];
        if ([remoteError isKindOfClass:[NSDictionary class]]) {
            failure = [NSError errorWithDomain:remoteError[@"domain"] code:[remoteError[@"code"] integerValue]
                userInfo:@{NSLocalizedDescriptionKey : remoteError[@"message"]}];
            break;
        }
        id values = response[@"identifiers"];
        BOOL valid = [values isKindOfClass:[NSArray class]];
        if (valid) {
            for (id value in values) {
                if (![value isKindOfClass:[NSString class]] || [value length] == 0) {
                    valid = NO;
                    break;
                }
            }
        }
        if (!valid) {
            failure = KayokoApplicationBridgeError(2, @"Invalid application catalog response");
            break;
        }
        identifiers = values;
    } while (NO);
    if (token != -1) {
        notify_cancel(token);
    }
    for (NSString *path in @[[self requestPath], [self responsePath]]) {
        if ([KayokoReadApplicationMessage(path)[@"requestID"] isEqual:requestID]) {
            [files removeItemAtPath:path error:nil];
        }
    }
    if (error) {
        *error = failure;
    }
    return identifiers;
}

@end

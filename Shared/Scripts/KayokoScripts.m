#import "KayokoScripts.h"
#import <roothide.h>
#import <spawn.h>
#import <sys/wait.h>
#import <signal.h>
#import <unistd.h>
#import <errno.h>
#import <stdio.h>
#import <string.h>
#import <fcntl.h>
#import <sys/file.h>
#import <sys/stat.h>

NSString *KayokoScriptString(NSString *key) {
    NSBundle *bundle = [NSBundle bundleWithPath:jbroot(@"/Library/PreferenceBundles/KayokoPreferences.bundle")];
    return [bundle localizedStringForKey:key value:key table:@"Tweak"] ?: key;
}

@implementation KayokoScripts

+ (NSString *)path {
    return jbroot(@"/var/mobile/Library/com.mlgm.kayoko/scripts.plist");
}

+ (BOOL)isValidScript:(NSDictionary *)item {
    if (![item isKindOfClass:NSDictionary.class]) return NO;
    for (NSString *key in @[@"id", @"name", @"code", @"input"])
        if (![item[key] isKindOfClass:NSString.class] || (![key isEqualToString:@"input"] && ![item[key] length])) return NO;
    return [item[@"enabled"] isKindOfClass:NSNumber.class] &&
           CFGetTypeID((__bridge CFTypeRef)item[@"enabled"]) == CFBooleanGetTypeID();
}

+ (NSError *)invalidLibraryError {
    return [NSError errorWithDomain:@"com.mlgm.kayoko.scripts" code:1 userInfo:
        @{NSLocalizedDescriptionKey:KayokoScriptString(@"Invalid script library")}];
}

+ (NSArray<NSDictionary *> *)readScriptsWithError:(NSError **)error {
    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfFile:self.path options:0 error:&readError];
    if (!data) {
        if ([readError.domain isEqualToString:NSCocoaErrorDomain] && readError.code == NSFileReadNoSuchFileError) return @[];
        if (error) *error = readError;
        return nil;
    }
    id items = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:nil];
    if ([items isKindOfClass:NSArray.class]) {
        NSMutableSet *ids = [NSMutableSet set];
        for (NSDictionary *item in items) {
            if (![self isValidScript:item] || [ids containsObject:item[@"id"]]) {
                if (error) *error = [self invalidLibraryError];
                return nil;
            }
            [ids addObject:item[@"id"]];
        }
        return items;
    }
    if (error) *error = [self invalidLibraryError];
    return nil;
}

+ (NSURL *)bundledScriptsURL {
    NSBundle *bundle = [NSBundle bundleWithPath:jbroot(@"/Library/PreferenceBundles/KayokoPreferences.bundle")];
    return [bundle URLForResource:@"BundledScripts" withExtension:@"plist"];
}

+ (BOOL)addBundledScriptsWithError:(NSError **)error {
    NSArray *current = [self readScriptsWithError:error];
    if (!current) return NO;
    NSURL *url = [self bundledScriptsURL];
    NSArray *defaults = url ? [NSArray arrayWithContentsOfURL:url error:error] : nil;
    if (!defaults || defaults.count == 0) {
        if (error && (!url || defaults)) *error = [self invalidLibraryError];
        return NO;
    }
    NSMutableArray *items = [current mutableCopy];
    NSMutableSet *ids = [NSMutableSet setWithArray:[current valueForKey:@"id"]];
    for (NSDictionary *script in defaults) {
        if (![self isValidScript:script]) { if (error) *error = [self invalidLibraryError]; return NO; }
        if ([ids containsObject:script[@"id"]]) continue;
        NSMutableDictionary *local = [script mutableCopy];
        local[@"name"] = KayokoScriptString(script[@"name"]);
        [items addObject:local];
        [ids addObject:script[@"id"]];
    }
    return items.count == current.count || [self writeScripts:items error:error];
}

+ (BOOL)withLibraryLock:(BOOL (^)(NSError **))operation error:(NSError **)error {
    NSString *dir = self.path.stringByDeletingLastPathComponent;
    if (![NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    NSString *marker = [dir stringByAppendingPathComponent:@"bundled-scripts.ready"];
    int fd = open(marker.fileSystemRepresentation, O_RDWR | O_CREAT | O_CLOEXEC, 0600);
    struct stat info;
    BOOL ok = fd >= 0 && flock(fd, LOCK_EX) == 0 && fstat(fd, &info) == 0;
    NSError *failure = nil;
    if (ok && !info.st_size) ok = [self addBundledScriptsWithError:&failure] && pwrite(fd, "1", 1, 0) == 1;
    if (ok && operation) ok = operation(&failure);
    if (!ok && error) *error = failure ?: [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
    if (fd >= 0) close(fd);
    return ok;
}

+ (NSArray<NSDictionary *> *)scriptsWithError:(NSError **)error {
    NSString *marker = [self.path.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"bundled-scripts.ready"];
    struct stat info;
    if ((stat(marker.fileSystemRepresentation, &info) != 0 || info.st_size != 1) && ![self withLibraryLock:nil error:error]) return nil;
    return [self readScriptsWithError:error];
}

+ (BOOL)writeScripts:(NSArray<NSDictionary *> *)scripts error:(NSError **)error {
    NSURL *url = [NSURL fileURLWithPath:self.path];
    if (![[NSFileManager defaultManager] createDirectoryAtURL:url.URLByDeletingLastPathComponent
                                   withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:scripts format:NSPropertyListBinaryFormat_v1_0 options:0 error:error];
    return data && [data writeToURL:url options:NSDataWritingAtomic error:error];
}

+ (NSArray *)updateScripts:(NSArray *(^)(NSMutableArray *, NSError **))update error:(NSError **)error {
    __block NSArray *saved;
    BOOL ok = [self withLibraryLock:^BOOL(NSError **failure) {
        NSArray *items = [self readScriptsWithError:failure];
        if (!items) return NO;
        saved = update([items mutableCopy], failure);
        return saved && ([saved isEqualToArray:items] || [self writeScripts:saved error:failure]);
    } error:error];
    return ok ? saved : nil;
}

+ (BOOL)saveScript:(NSDictionary *)script error:(NSError **)error {
    if (![self isValidScript:script]) {
        if (error) *error = [self invalidLibraryError];
        return NO;
    }
    return [self updateScripts:^NSArray *(NSMutableArray *items, NSError **failure) {
        NSUInteger index = [[items valueForKey:@"id"] indexOfObject:script[@"id"]];
        if (index == NSNotFound) [items addObject:script];
        else items[index] = script;
        return items;
    } error:error] != nil;
}

+ (BOOL)deleteScriptWithID:(NSString *)identifier error:(NSError **)error {
    return [self updateScripts:^NSArray *(NSMutableArray *items, NSError **failure) {
        NSUInteger index = [[items valueForKey:@"id"] indexOfObject:identifier];
        if (index != NSNotFound) [items removeObjectAtIndex:index];
        return items;
    } error:error] != nil;
}

+ (NSArray<NSDictionary *> *)reorderScriptsWithIDs:(NSArray<NSString *> *)identifiers error:(NSError **)error {
    return [self updateScripts:^NSArray *(NSMutableArray *items, NSError **failure) {
        NSArray *oldIDs = [items valueForKey:@"id"];
        if (items.count != identifiers.count || ![[NSSet setWithArray:oldIDs] isEqualToSet:[NSSet setWithArray:identifiers]]) {
            *failure = [NSError errorWithDomain:@"com.mlgm.kayoko.scripts" code:2
                userInfo:@{NSLocalizedDescriptionKey:KayokoScriptString(@"Scripts changed. Try moving the script again.")}];
            return nil;
        }
        NSDictionary *byID = [NSDictionary dictionaryWithObjects:items forKeys:oldIDs];
        return [byID objectsForKeys:identifiers notFoundMarker:NSNull.null];
    } error:error];
}

+ (NSDictionary *)execute:(NSData *)request {
    FILE *input = tmpfile(), *output = tmpfile();
    NSDictionary *reply = nil;
    if (input && output && fwrite(request.bytes, 1, request.length, input) == request.length && fseek(input, 0, SEEK_SET) == 0) {
        const char *path = [jbroot(@"/usr/local/libexec/kayoko_script") fileSystemRepresentation];
        char * const args[] = {(char *)path, NULL};
        char * const env[] = {NULL};
        posix_spawn_file_actions_t actions;
        posix_spawn_file_actions_init(&actions);
        posix_spawn_file_actions_adddup2(&actions, fileno(input), STDIN_FILENO);
        posix_spawn_file_actions_adddup2(&actions, fileno(output), STDOUT_FILENO);
        posix_spawnattr_t attr;
        posix_spawnattr_init(&attr);
        posix_spawnattr_setflags(&attr, POSIX_SPAWN_CLOEXEC_DEFAULT);
        pid_t child;
        int spawnError = posix_spawn(&child, path, &actions, &attr, args, env);
        posix_spawnattr_destroy(&attr);
        posix_spawn_file_actions_destroy(&actions);
        if (spawnError) reply = @{@"error":[NSString stringWithFormat:@"%@: %s", KayokoScriptString(@"Cannot start script"), strerror(spawnError)]};
        else {
            NSTimeInterval until = NSProcessInfo.processInfo.systemUptime + 2.0;
            int status = 0;
            pid_t done;
            do {
                done = waitpid(child, &status, WNOHANG);
                if (done == child || (done < 0 && errno != EINTR)) break;
                usleep(10000);
            } while (NSProcessInfo.processInfo.systemUptime < until);
            if (done == 0 || (done < 0 && errno == EINTR)) {
                kill(child, SIGKILL);
                while (waitpid(child, &status, 0) < 0 && errno == EINTR) {}
                reply = @{@"status":@"Script timed out"};
            } else if (done == child && WIFSIGNALED(status) && WTERMSIG(status) == SIGXCPU) {
                reply = @{@"status":@"Script timed out"};
            } else if (done == child && WIFEXITED(status) && WEXITSTATUS(status) == 0 &&
                       fseek(output, 0, SEEK_END) == 0) {
                long size = ftell(output);
                if (size > 0 && size <= 1024 * 1024) {
                    rewind(output);
                    NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)size];
                    if (fread(data.mutableBytes, 1, size, output) == (size_t)size)
                        reply = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                }
            }
        }
    }
    if (input) fclose(input);
    if (output) fclose(output);
    return reply ?: @{@"status":@"Script did not finish"};
}

+ (void)runCode:(NSString *)code input:(NSString *)input
     completion:(void (^)(NSArray<NSString *> *, NSString *))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        if (![code isKindOfClass:NSString.class] || ![input isKindOfClass:NSString.class]) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, KayokoScriptString(@"Invalid script library")); });
            return;
        }
        const NSUInteger limit = 1024 * 1024;
        NSData *data = nil;
        if (code.length <= limit && input.length <= limit - code.length) {
            data = [NSJSONSerialization dataWithJSONObject:@{@"code":code, @"input":input} options:0 error:nil];
        }
        NSDictionary *reply = data && data.length <= limit ? [self execute:data] : @{@"status":@"Input is too large"};
        NSString *error = reply[@"error"] ?: (reply[@"status"] ? KayokoScriptString(reply[@"status"]) : nil);
        dispatch_async(dispatch_get_main_queue(), ^{ completion(reply[@"results"], error); });
    });
}
@end

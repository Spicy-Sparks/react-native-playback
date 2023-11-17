#import "Playback.h"
#import "Player.h"
#import <AVFoundation/AVFoundation.h>

@implementation Playback

RCT_EXPORT_MODULE()

static NSMutableDictionary *players = [NSMutableDictionary dictionary];

RCT_EXPORT_METHOD(createPlayer:(NSString *)playerId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    Player *player = [[Player alloc] initWithEventEmitterAndId:self playerId:playerId];
    [players setObject:player forKey:playerId];
    resolve(player.playerId);
}

RCT_EXPORT_METHOD(disposePlayer:(NSString *)playerId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    Player *player = [players objectForKey:playerId];
    if(player == nil) {
        reject(@"E_PLAYER_NOT_FOUND", @"playerId is invalid", nil);
        return;
    }
    [player dispose];
    [players removeObjectForKey:playerId];
    resolve(nil);
}

RCT_EXPORT_METHOD(setSource:(NSString *)playerId
                  source:(NSDictionary *)source
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    Player *player = [players objectForKey:playerId];
    if(player == nil) {
        reject(@"E_PLAYER_NOT_FOUND", @"playerId is invalid", nil);
        return;
    }
    [player setSource:source];
    resolve(nil);
}

RCT_EXPORT_METHOD(play:(NSString *)playerId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    Player *player = [players objectForKey:playerId];
    if(player == nil) {
        reject(@"E_PLAYER_NOT_FOUND", @"playerId is invalid", nil);
        return;
    }
    [player play];
    resolve(nil);
}

RCT_EXPORT_METHOD(pause:(NSString *)playerId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    Player *player = [players objectForKey:playerId];
    if(player == nil) {
        reject(@"E_PLAYER_NOT_FOUND", @"playerId is invalid", nil);
        return;
    }
    [player pause];
    resolve(nil);
}

RCT_EXPORT_METHOD(setVolume:(NSString *)playerId
                  volume:(nonnull NSNumber *)volume
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    Player *player = [players objectForKey:playerId];
    if(player == nil) {
        reject(@"E_PLAYER_NOT_FOUND", @"playerId is invalid", nil);
        return;
    }
    [player setVolume:volume];
    resolve(nil);
}

RCT_EXPORT_METHOD(setLoop:(NSString *)playerId
                  loop:(BOOL)loop
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    Player *player = [players objectForKey:playerId];
    if(player == nil) {
        reject(@"E_PLAYER_NOT_FOUND", @"playerId is invalid", nil);
        return;
    }
    [player setLoop:loop];
    resolve(nil);
}

RCT_EXPORT_METHOD(seek:(NSString *)playerId
                  seek:(NSDictionary *)seek
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    Player *player = [players objectForKey:playerId];
    if(player == nil) {
        reject(@"E_PLAYER_NOT_FOUND", @"playerId is invalid", nil);
        return;
    }
    [player seek:seek];
    resolve(nil);
}

+ (NSMutableDictionary *)players {
    return players;
}

- (NSArray<NSString *> *)supportedEvents {
    return @[@"playerEvent"];
}

@end

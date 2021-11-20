#include "DarwinAVPlayer.h"
#include "../../../FileItem.h"

#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

@interface AVPlayerObserver : NSObject
@property (nonatomic, weak) AVPlayer* player;
@end
@implementation AVPlayerObserver

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    AVPlayerItem* item = object;
    NSLog(@"%@ %@ %@", object, change, item.error);
    if (item.status == AVPlayerItemStatusReadyToPlay)
        [self.player play];
}

@end

struct DarwinAVPlayerImpl
{
    AVQueuePlayer* player;
    AVPlayerView* view;
    AVPlayerObserver* playerObserver;

    DarwinAVPlayerImpl() : player{[AVQueuePlayer new]}, view{[AVPlayerView new]}, playerObserver{[AVPlayerObserver new]}
    {
        view.player = player;
        playerObserver.player = player;
    }

    void setNewPlayerItem(AVPlayerItem* _Nullable item)
    {
        const auto statusKeyPath = NSStringFromSelector(@selector(status));
        [player.currentItem removeObserver:playerObserver forKeyPath:statusKeyPath];

        [item addObserver:playerObserver forKeyPath:statusKeyPath options:NSKeyValueObservingOptionNew context:nullptr];
        [player replaceCurrentItemWithPlayerItem:item];
    }
};


DarwinAVPlayer::DarwinAVPlayer(IPlayerCallback& callback) : IPlayer{callback}, m_impl{std::make_unique<DarwinAVPlayerImpl>()}
{
//    [m_impl->view setFrameSize:NSApp.mainWindow.contentView.bounds.size];
    [m_impl->view setFrameSize:NSMakeSize(1280, 720)];
    [NSApp.windows.lastObject.contentView addSubview:m_impl->view];
}

DarwinAVPlayer::~DarwinAVPlayer() = default;

bool DarwinAVPlayer::OpenFile(const CFileItem& file, const CPlayerOptions& options)
{
    const auto filePath = [NSString stringWithUTF8String:file.GetPath().c_str()];
    NSLog(@"%s %@", __PRETTY_FUNCTION__, filePath);
    const auto playerItem = [AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:filePath isDirectory:NO]];
    m_impl->setNewPlayerItem(playerItem);
    return true;
}

bool DarwinAVPlayer::QueueNextFile(const CFileItem &file)
{
    return false;
}

bool DarwinAVPlayer::CloseFile(bool reopen)
{
    m_impl->setNewPlayerItem(nil);
    return true;
}

bool DarwinAVPlayer::IsPlaying() const
{
    return m_impl->player.rate != 0;
}

void DarwinAVPlayer::Pause()
{
    if (IsPlaying())
        [m_impl->player pause];
    else
        [m_impl->player play];
}

bool DarwinAVPlayer::HasVideo() const
{
    return true;
}

bool DarwinAVPlayer::HasAudio() const
{
    return false;
}

void DarwinAVPlayer::Seek(bool bPlus, bool bLargeStep, bool bChapterOverride)
{

}

void DarwinAVPlayer::SeekPercentage(float fPercent)
{
    NSLog(@"%s %f", __PRETTY_FUNCTION__, fPercent);
}

void DarwinAVPlayer::SetMute(bool bOnOff)
{
    m_impl->player.muted = bOnOff;
}

void DarwinAVPlayer::SetVolume(float volume)
{
    m_impl->player.volume = volume;
}

void DarwinAVPlayer::SeekTime(int64_t iTime)
{
    NSLog(@"%s %lld", __PRETTY_FUNCTION__, iTime);
}

bool DarwinAVPlayer::SeekTimeRelative(int64_t iTime)
{
    NSLog(@"%s %lld", __PRETTY_FUNCTION__, iTime);
    return false;
}

void DarwinAVPlayer::SetTime(int64_t time)
{
    NSLog(@"%s %lld", __PRETTY_FUNCTION__, time);
}

void DarwinAVPlayer::SetTotalTime(int64_t time)
{
    NSLog(@"%s %lld", __PRETTY_FUNCTION__, time);
}

void DarwinAVPlayer::SetSpeed(float speed)
{

}

#pragma once

#include "../../../cores/IPlayer.h"

#include <memory>

struct DarwinAVPlayerImpl;

class DarwinAVPlayer : public IPlayer
{
public:
    explicit DarwinAVPlayer(IPlayerCallback& callback);
    ~DarwinAVPlayer();

    bool OpenFile(const CFileItem& file, const CPlayerOptions& options) override;
    bool QueueNextFile(const CFileItem &file) override;
    bool CloseFile(bool reopen = false) override;
    bool IsPlaying() const override;
    void Pause() override;
    bool HasVideo() const override;
    bool HasAudio() const override;
    void Seek(bool bPlus = true, bool bLargeStep = false, bool bChapterOverride = false) override;
    void SeekPercentage(float fPercent = 0) override;
    void SetMute(bool bOnOff) override;
    void SetVolume(float volume) override;

    void SeekTime(int64_t iTime = 0) override;
    bool SeekTimeRelative(int64_t iTime) override;
    void SetTime(int64_t time) override;
    void SetTotalTime(int64_t time) override;
    void SetSpeed(float speed) override;

private:
    std::unique_ptr<DarwinAVPlayerImpl> m_impl;
};

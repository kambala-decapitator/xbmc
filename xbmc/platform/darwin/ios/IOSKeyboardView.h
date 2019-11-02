/*
 *  Copyright (C) 2019- Team Kodi
 *  This file is part of Kodi - https://kodi.tv
 *
 *  SPDX-License-Identifier: GPL-2.0-or-later
 *  See LICENSES/README.md for more information.
 */

#import "platform/darwin/ios-common/DarwinEmbedKeyboardView.h"

typedef NS_ENUM(NSUInteger, ShowKeyboardState) {
  KEYBOARD_NOT_SHOW,
  KEYBOARD_WILL_SHOW,
  KEYBOARD_SHOWING
};

@interface IOSKeyboardView : KeyboardView
{
  ShowKeyboardState m_keyboardIsShowing;
}

- (instancetype)initWithFrame:(CGRect)frame;

@end

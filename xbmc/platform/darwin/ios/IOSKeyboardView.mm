/*
 *  Copyright (C) 2019- Team Kodi
 *  This file is part of Kodi - https://kodi.tv
 *
 *  SPDX-License-Identifier: GPL-2.0-or-later
 *  See LICENSES/README.md for more information.
 */

#import "IOSKeyboardView.h"

#import "utils/log.h"

@implementation IOSKeyboardView : KeyboardView

- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (!self)
    return nil;

  m_keyboardIsShowing = KEYBOARD_NOT_SHOW;

  [self setAlpha:0.9];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(keyboardDidHide:)
                                               name:UIKeyboardDidHideNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(keyboardDidChangeFrame:)
                                               name:UIKeyboardDidChangeFrameNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(keyboardWillShow:)
                                               name:UIKeyboardWillShowNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(keyboardDidShow:)
                                               name:UIKeyboardDidShowNotification
                                             object:nil];

  return self;

}

- (void)keyboardWillShow:(NSNotification*)notification
{
  NSDictionary* info = [notification userInfo];
  CGRect kbRect = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
  CLog::Log(LOGDEBUG, "keyboardWillShow: keyboard frame: {}", NSStringFromCGRect(kbRect).UTF8String);
  m_kbRect = kbRect;
  [self setNeedsLayout];
  m_keyboardIsShowing = KEYBOARD_WILL_SHOW;
}

- (void)keyboardDidShow:(NSNotification*)notification
{
  CLog::Log(LOGDEBUG, "keyboardDidShow: deactivated: {}", m_deactivated);
  m_keyboardIsShowing = KEYBOARD_SHOWING;
  if (m_deactivated)
    [self deactivate];
}

- (void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event
{
  [m_inputTextField resignFirstResponder];
}

- (BOOL)textFieldShouldEndEditing:(UITextField*)textField
{
  CLog::Log(LOGDEBUG, "{}: keyboard IsShowing {}", __PRETTY_FUNCTION__, m_keyboardIsShowing);
  // Do not break the keyboard show up process, else we will lose
  // keyboard did hide notification.
  return m_keyboardIsShowing != KEYBOARD_WILL_SHOW;
}

- (BOOL)textFieldShouldReturn:(UITextField*)textField
{
  [m_inputTextField resignFirstResponder];

  return [super textFieldShouldReturn:textField];;
}

- (void)keyboardDidChangeFrame:(id)sender
{
}

- (void)keyboardDidHide:(id)sender
{
  m_keyboardIsShowing = KEYBOARD_NOT_SHOW;

  if (m_inputTextField.editing)
  {
    CLog::Log(LOGDEBUG, "kb hide when editing, it could be a language switch");
    return;
  }

  [self deactivate];
}

- (void)deactivate
{
  CLog::Log(LOGDEBUG, "{}: keyboard IsShowing {}", __PRETTY_FUNCTION__, m_keyboardIsShowing);

  // Do not break keyboard show up process, if so there's a bug of ios4 will not
  // notify us keyboard hide.
  if (m_keyboardIsShowing == KEYBOARD_WILL_SHOW)
    return;
    
  [super deactivate];
}

@end

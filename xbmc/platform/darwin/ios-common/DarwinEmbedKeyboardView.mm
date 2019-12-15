/*
 *  Copyright (C) 2012-2018 Team Kodi
 *  This file is part of Kodi - https://kodi.tv
 *
 *  SPDX-License-Identifier: GPL-2.0-or-later
 *  See LICENSES/README.md for more information.
 */

#import "DarwinEmbedKeyboardView.h"

#include "Application.h"
#include "guilib/GUIKeyboardFactory.h"
#include "threads/Event.h"
#include "utils/log.h"

#import "platform/darwin/ios/XBMCController.h"

static CEvent keyboardFinishedEvent;

//@interface KeyboardView ()
//@property (nonatomic, weak) UITextField* inputTextField;
//@property (nonatomic, weak) UILabel* inputTextHeading;
//@end

@implementation KeyboardView

@synthesize confirmed = m_confirmed;
@synthesize darwinEmbedKeyboard = m_darwinEmbedKeyboard;
//@synthesize inputTextField = m_inputTextField;
//@synthesize inputTextHeading = m_inputTextHeading;
//@synthesize text = m_text;

- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (!self)
    return nil;

//  m_confirmed = NO;
  m_canceled = nullptr;
//  m_deactivated = NO;

//  m_text = [NSMutableString new];

  // default input box position above the half screen.
//  CGRect textFieldFrame =
//      CGRectMake(frame.size.width / 2,
//                 frame.size.height / 2 - INPUT_BOX_HEIGHT - SPACE_BETWEEN_INPUT_AND_KEYBOARD,
//                 frame.size.width / 2, INPUT_BOX_HEIGHT);
  auto textField = [UITextField new];
  textField.translatesAutoresizingMaskIntoConstraints = NO;
  textField.clearButtonMode = UITextFieldViewModeAlways;
  textField.borderStyle = UITextBorderStyleNone;
  textField.returnKeyType = UIReturnKeyDone;
  textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
  textField.backgroundColor = UIColor.whiteColor;
//  textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
  textField.delegate = self;
  [self addSubview:textField];
  m_inputTextField = textField;

  self.userInteractionEnabled = YES;

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(textChanged:)
                                               name:UITextFieldTextDidChangeNotification
                                             object:m_inputTextField];
  return self;
}

//- (void)layoutSubviews
//{
//  CGFloat headingW = 0;
//  if (m_inputTextHeading.text && m_inputTextHeading.text.length > 0)
//  {
//    CGSize headingSize = [m_inputTextHeading.text sizeWithAttributes:@{
//      NSFontAttributeName : [UIFont systemFontOfSize:[UIFont systemFontSize]]
//    }];
//
//    headingW = MIN(self.bounds.size.width / 2, headingSize.width + 30);
//  }
//
//  CGFloat y = m_kbRect.origin.y - INPUT_BOX_HEIGHT - SPACE_BETWEEN_INPUT_AND_KEYBOARD;
//
//  m_inputTextHeading.frame = CGRectMake(0, y, headingW, INPUT_BOX_HEIGHT);
//  m_inputTextField.frame = CGRectMake(headingW, y, self.bounds.size.width - headingW, INPUT_BOX_HEIGHT);
//}

- (void)textFieldDidEndEditing:(UITextField*)textField
{
  [self deactivate];
}

- (BOOL)textFieldShouldReturn:(UITextField*)textField
{
  m_confirmed = YES;

  return YES;
}

- (NSString*)text
{
  NSString __block* result;
  dispatch_sync(dispatch_get_main_queue(), ^{
    result = m_inputTextField.text;
  });
  return result;
}

- (void)activate
{
  dispatch_sync(dispatch_get_main_queue(), ^{
    [g_xbmcController activateKeyboard:self];
    [self layoutIfNeeded];
    [m_inputTextField becomeFirstResponder];
    keyboardFinishedEvent.Reset();
  });

  // we are waiting on the user finishing the keyboard
  while (!keyboardFinishedEvent.WaitMSec(500))
  {
    if (nullptr != m_canceled && *m_canceled)
    {
      [self deactivate];
      m_canceled = nullptr;
    }
  }
}

- (void)deactivate
{
  m_deactivated = YES;

  // invalidate our callback object
  if (m_darwinEmbedKeyboard)
  {
    m_darwinEmbedKeyboard->invalidateCallback();
    m_darwinEmbedKeyboard = nil;
  }
  // give back the control to whoever
  [m_inputTextField resignFirstResponder];

  // delay closing view until text field finishes resigning first responder
  dispatch_async(dispatch_get_main_queue(), ^{
    // always called in the mainloop context
    // detach the keyboard view from our main controller
    [g_xbmcController deactivateKeyboard:self];

    // no more notification we want to receive.
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    keyboardFinishedEvent.Set();
  });
}

- (void)setKeyboardText:(NSString*)aText closeKeyboard:(BOOL)closeKeyboard
{
  CLog::Log(LOGDEBUG, "{}: {}, {}", __PRETTY_FUNCTION__, aText.UTF8String, closeKeyboard);

  dispatch_sync(dispatch_get_main_queue(), ^{
    m_inputTextField.text = aText;
    [self textChanged:nil];
  });

  if (closeKeyboard)
  {
    m_confirmed = YES;
    [self deactivate];
  }
}

- (void)setHeading:(NSString*)heading
{
  dispatch_sync(dispatch_get_main_queue(), ^{
//    m_inputTextHeading.text = [heading stringByAppendingString:@" "];
    m_inputTextField.placeholder = heading;
  });
}

- (void)setHidden:(BOOL)hidden
{
  dispatch_sync(dispatch_get_main_queue(), ^{
    m_inputTextField.secureTextEntry = hidden;
  });

}

- (void)textChanged:(NSNotification*)aNotification
{
//  if (![self.text isEqualToString:m_inputTextField.text])
//  {
//    [self.text setString:m_inputTextField.text];
    if (m_darwinEmbedKeyboard)
      m_darwinEmbedKeyboard->fireCallback(m_inputTextField.text.UTF8String);
//  }
}

- (void)setCancelFlag:(bool*)cancelFlag
{
  m_canceled = cancelFlag;
}

@end

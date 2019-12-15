/*
 *  Copyright (C) 2019- Team Kodi
 *  This file is part of Kodi - https://kodi.tv
 *
 *  SPDX-License-Identifier: GPL-2.0-or-later
 *  See LICENSES/README.md for more information.
 */

#import "IOSKeyboardView.h"

#import "utils/log.h"

static const CGFloat INPUT_BOX_HEIGHT = 30;

typedef NS_ENUM(NSUInteger, ShowKeyboardState) {
  KEYBOARD_NOT_SHOW,
  KEYBOARD_WILL_SHOW,
  KEYBOARD_SHOWING
};

@interface IOSKeyboardView ()
@property(nonatomic, weak) UIView* textFieldContainer;
@property(nonatomic, weak) NSLayoutConstraint* containerBottomConstraint;
@property(nonatomic, assign) ShowKeyboardState keyboardIsShowing;
@end

@implementation IOSKeyboardView : KeyboardView

@synthesize textFieldContainer = m_textFieldContainer;
@synthesize containerBottomConstraint = m_containerBottomConstraint;
@synthesize keyboardIsShowing = m_keyboardIsShowing;

- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (!self)
    return nil;

  m_keyboardIsShowing = KEYBOARD_NOT_SHOW;

  self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.1];

  auto notificationCenter = NSNotificationCenter.defaultCenter;
  [notificationCenter addObserver:self
                         selector:@selector(keyboardDidHide:)
                             name:UIKeyboardDidHideNotification
                           object:nil];
  [notificationCenter addObserver:self
                         selector:@selector(keyboardDidChangeFrame:)
                             name:UIKeyboardDidChangeFrameNotification
                           object:nil];
  [notificationCenter addObserver:self
                         selector:@selector(keyboardWillShow:)
                             name:UIKeyboardWillShowNotification
                           object:nil];
  [notificationCenter addObserver:self
                         selector:@selector(keyboardDidShow:)
                             name:UIKeyboardDidShowNotification
                           object:nil];

  [self addGestureRecognizer:[[UITapGestureRecognizer alloc]
                                 initWithTarget:m_inputTextField
                                         action:@selector(resignFirstResponder)]];

  auto textFieldContainer = [UIView new];
  textFieldContainer.translatesAutoresizingMaskIntoConstraints = NO;
  textFieldContainer.backgroundColor = UIColor.whiteColor;
  [textFieldContainer addSubview:m_inputTextField];
  [self addSubview:textFieldContainer];
  m_textFieldContainer = textFieldContainer;

  auto constraint = [textFieldContainer.bottomAnchor constraintEqualToAnchor:self.topAnchor];
  m_containerBottomConstraint = constraint;

  [NSLayoutConstraint activateConstraints:@[
    constraint,
    [textFieldContainer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
    [textFieldContainer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
    [textFieldContainer.heightAnchor constraintEqualToConstant:INPUT_BOX_HEIGHT],

    [m_inputTextField.widthAnchor constraintEqualToAnchor:textFieldContainer.widthAnchor
                                               multiplier:0.5],
    [m_inputTextField.centerXAnchor constraintEqualToAnchor:textFieldContainer.centerXAnchor],
    [m_inputTextField.topAnchor constraintEqualToAnchor:textFieldContainer.topAnchor],
    [m_inputTextField.bottomAnchor constraintEqualToAnchor:textFieldContainer.bottomAnchor],
  ]];

  return self;

}

- (void)keyboardWillShow:(NSNotification*)notification
{
  auto keyboardState = self.keyboardIsShowing;
  self.keyboardIsShowing = KEYBOARD_WILL_SHOW;
  if (keyboardState == KEYBOARD_NOT_SHOW)
    self.textFieldContainer.hidden = YES;
}

- (void)keyboardDidShow:(NSNotification*)notification
{
  self.keyboardIsShowing = KEYBOARD_SHOWING;
  self.textFieldContainer.hidden = NO;

  CLog::Log(LOGDEBUG, "keyboardDidShow: deactivated: {}", m_deactivated);
  if (m_deactivated)
    [self deactivate];
}

- (BOOL)textFieldShouldEndEditing:(UITextField*)textField
{
  CLog::Log(LOGDEBUG, "{}: keyboard IsShowing {}", __PRETTY_FUNCTION__, self.keyboardIsShowing);
  // Do not break the keyboard show up process, else we will lose
  // keyboard did hide notification.
  return self.keyboardIsShowing != KEYBOARD_WILL_SHOW;
}

- (BOOL)textFieldShouldReturn:(UITextField*)textField
{
  auto result = [super textFieldShouldReturn:textField];
  if (result)
    [textField resignFirstResponder];
  return result;
}

- (void)keyboardDidChangeFrame:(NSNotification*)notification
{
  auto keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
  // although converting isn't really necessary in our case, as the holder view occupies
  // the whole screen, technically it's more correct
  auto convertedFrame = [self convertRect:keyboardFrame
                      fromCoordinateSpace:UIScreen.mainScreen.coordinateSpace];
  self.containerBottomConstraint.constant = CGRectGetMinY(convertedFrame);
  [self layoutIfNeeded];
}

- (void)keyboardDidHide:(id)sender
{
  if (m_inputTextField.editing)
  {
    CLog::Log(LOGDEBUG, "kb hide when editing, it could be a language switch");
    return;
  }

  self.keyboardIsShowing = KEYBOARD_NOT_SHOW;
  [self deactivate];
}

- (void)deactivate
{
  CLog::Log(LOGDEBUG, "{}: keyboard IsShowing {}", __PRETTY_FUNCTION__, self.keyboardIsShowing);

  // Do not break keyboard show up process, if so there's a bug of ios4 will not
  // notify us keyboard hide.
  if (self.keyboardIsShowing == KEYBOARD_WILL_SHOW)
    return;
    
  [super deactivate];
}

@end

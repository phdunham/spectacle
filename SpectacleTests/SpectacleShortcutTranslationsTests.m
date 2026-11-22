#import "SpectacleTestSupport.h"
#import <Carbon/Carbon.h>

#import "SpectacleShortcut.h"
#import "SpectacleShortcutTranslations.h"

static SpectacleShortcut *shortcutForKeyBinding(NSString *keyBinding);

@interface SpectacleShortcutTranslationsTests : XCTestCase
@end

@implementation SpectacleShortcutTranslationsTests

- (void)testTranslateAlphanumericKeyCodes
{
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_A), @"A");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_B), @"B");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_C), @"C");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_D), @"D");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_E), @"E");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_F), @"F");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_G), @"G");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_H), @"H");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_I), @"I");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_J), @"J");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_K), @"K");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_L), @"L");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_M), @"M");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_N), @"N");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_O), @"O");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_P), @"P");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_Q), @"Q");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_R), @"R");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_S), @"S");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_T), @"T");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_U), @"U");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_V), @"V");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_W), @"W");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_X), @"X");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_Y), @"Y");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_Z), @"Z");

  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_0), @"0");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_1), @"1");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_2), @"2");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_3), @"3");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_4), @"4");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_5), @"5");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_6), @"6");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_7), @"7");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_8), @"8");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_9), @"9");
}

- (void)testTranslateKeyboardLayoutIndependentKeyCodes
{
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_F1), @"F1");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_F2), @"F2");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_F3), @"F3");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_F4), @"F4");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_F5), @"F5");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_F6), @"F6");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_F7), @"F7");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_F8), @"F8");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_F9), @"F9");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_F10), @"F10");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_F11), @"F11");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_F12), @"F12");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_F13), @"F13");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_F14), @"F14");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_F15), @"F15");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_F16), @"F16");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_F17), @"F17");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_F18), @"F18");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_F19), @"F19");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_F20), @"F20");

  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_KeypadDecimal), @".");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_KeypadMultiply), @"*");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_KeypadPlus), @"+");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_KeypadClear), @"⌧");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_KeypadDivide), @"/");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_KeypadEnter), @"⌤");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_KeypadMinus), @"-");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_KeypadEquals), @"=");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_Keypad0), @"0");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_Keypad1), @"1");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_Keypad2), @"2");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_Keypad3), @"3");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_Keypad4), @"4");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_Keypad5), @"5");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_Keypad6), @"6");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_Keypad7), @"7");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_Keypad8), @"8");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ANSI_Keypad9), @"9");

  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_Return), @"↩");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_Tab), @"⇥");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_Space), @"␣");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_Delete), @"⌫");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_Escape), @"⎋");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_Command), @"⌘");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_Shift), @"⇧");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_CapsLock), @"⇪");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_Option), @"⌥");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_Control), @"⌃");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_RightShift), @"");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_RightOption), @"");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_RightControl), @"");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_Function), @"");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_VolumeUp), @"");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_VolumeDown), @"");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_Mute), @"");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_Help), @"");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_Home), @"↖");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_PageUp), @"⇞");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_ForwardDelete), @"⌦");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_End), @"↘");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_PageDown), @"⇟");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_LeftArrow), @"←");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_RightArrow), @"→");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_DownArrow), @"↓");
  SPTAssertEqual(SpectacleTranslateKeyCode(kVK_UpArrow), @"↑");
}

- (void)testTranslateEmptyModifiers
{
  SPTAssertEqual(SpectacleTranslateModifiers(0), @"");
}

- (void)testTranslateModifiers
{
  SPTAssertEqual(SpectacleTranslateModifiers(NSEventModifierFlagControl), @"⌃");
  SPTAssertEqual(SpectacleTranslateModifiers(NSEventModifierFlagOption), @"⌥");
  SPTAssertEqual(SpectacleTranslateModifiers(NSEventModifierFlagShift), @"⇧");
  SPTAssertEqual(SpectacleTranslateModifiers(NSEventModifierFlagCommand), @"⌘");

}

- (void)testTranslateShortcuts
{
  SPTAssertEqual(SpectacleTranslateShortcut(shortcutForKeyBinding(@"option+command+c")), @"⌥⌘C");
  SPTAssertEqual(SpectacleTranslateShortcut(shortcutForKeyBinding(@"option+command+f")), @"⌥⌘F");
  SPTAssertEqual(SpectacleTranslateShortcut(shortcutForKeyBinding(@"option+command+left")), @"⌥⌘←");
  SPTAssertEqual(SpectacleTranslateShortcut(shortcutForKeyBinding(@"option+command+right")), @"⌥⌘→");
  SPTAssertEqual(SpectacleTranslateShortcut(shortcutForKeyBinding(@"option+command+up")), @"⌥⌘↑");
  SPTAssertEqual(SpectacleTranslateShortcut(shortcutForKeyBinding(@"option+command+down")), @"⌥⌘↓");
  SPTAssertEqual(SpectacleTranslateShortcut(shortcutForKeyBinding(@"control+command+left")), @"⌃⌘←");
  SPTAssertEqual(SpectacleTranslateShortcut(shortcutForKeyBinding(@"control+shift+command+left")), @"⌃⇧⌘←");
  SPTAssertEqual(SpectacleTranslateShortcut(shortcutForKeyBinding(@"control+command+right")), @"⌃⌘→");
  SPTAssertEqual(SpectacleTranslateShortcut(shortcutForKeyBinding(@"control+shift+command+right")), @"⌃⇧⌘→");
  SPTAssertEqual(SpectacleTranslateShortcut(shortcutForKeyBinding(@"control+option+command+right")), @"⌃⌥⌘→");
  SPTAssertEqual(SpectacleTranslateShortcut(shortcutForKeyBinding(@"control+option+command+left")), @"⌃⌥⌘←");
  SPTAssertEqual(SpectacleTranslateShortcut(shortcutForKeyBinding(@"control+option+right")), @"⌃⌥→");
  SPTAssertEqual(SpectacleTranslateShortcut(shortcutForKeyBinding(@"control+option+left")), @"⌃⌥←");
  SPTAssertEqual(SpectacleTranslateShortcut(shortcutForKeyBinding(@"control+option+shift+right")), @"⌃⌥⇧→");
  SPTAssertEqual(SpectacleTranslateShortcut(shortcutForKeyBinding(@"control+option+shift+left")), @"⌃⌥⇧←");
  SPTAssertEqual(SpectacleTranslateShortcut(shortcutForKeyBinding(@"option+command+z")), @"⌥⌘Z");
  SPTAssertEqual(SpectacleTranslateShortcut(shortcutForKeyBinding(@"option+shift+command+z")), @"⌥⇧⌘Z");
}

- (void)testConvertEmptyModifiers
{
  SPTAssertEqual(SpectacleConvertCocoaModifiersToCarbon(0), 0);
  SPTAssertEqual(SpectacleConvertCarbonModifiersToCocoa(0), 0);
}

- (void)testConvertInvalidModifiers
{
  SPTAssertEqual(SpectacleConvertCocoaModifiersToCarbon(42), 0);
  SPTAssertEqual(SpectacleConvertCarbonModifiersToCocoa(42), 0);
}

- (void)testConvertCocoaModifiersToCarbonModifiers
{
  SPTAssertEqual(SpectacleConvertCocoaModifiersToCarbon(NSEventModifierFlagControl), controlKey);
  SPTAssertEqual(SpectacleConvertCocoaModifiersToCarbon(NSEventModifierFlagOption), optionKey);
  SPTAssertEqual(SpectacleConvertCocoaModifiersToCarbon(NSEventModifierFlagShift), shiftKey);
  SPTAssertEqual(SpectacleConvertCocoaModifiersToCarbon(NSEventModifierFlagCommand), cmdKey);
}

- (void)testConvertCarbonModifiersToCocoaModifiers
{
  SPTAssertEqual(SpectacleConvertCarbonModifiersToCocoa(controlKey), NSEventModifierFlagControl);
  SPTAssertEqual(SpectacleConvertCarbonModifiersToCocoa(optionKey), NSEventModifierFlagOption);
  SPTAssertEqual(SpectacleConvertCarbonModifiersToCocoa(shiftKey), NSEventModifierFlagShift);
  SPTAssertEqual(SpectacleConvertCarbonModifiersToCocoa(cmdKey), NSEventModifierFlagCommand);
}

- (void)testConvertModifiersToCarbonModifiersIfNecessary
{
  SPTAssertEqual(SpectacleConvertModifiersToCarbonIfNecessary(controlKey), controlKey);
  SPTAssertEqual(SpectacleConvertModifiersToCarbonIfNecessary(optionKey), optionKey);
  SPTAssertEqual(SpectacleConvertModifiersToCarbonIfNecessary(shiftKey), shiftKey);
  SPTAssertEqual(SpectacleConvertModifiersToCarbonIfNecessary(cmdKey), cmdKey);
  SPTAssertEqual(SpectacleConvertModifiersToCarbonIfNecessary(NSEventModifierFlagControl), controlKey);
  SPTAssertEqual(SpectacleConvertModifiersToCarbonIfNecessary(NSEventModifierFlagOption), optionKey);
  SPTAssertEqual(SpectacleConvertModifiersToCarbonIfNecessary(NSEventModifierFlagShift), shiftKey);
  SPTAssertEqual(SpectacleConvertModifiersToCarbonIfNecessary(NSEventModifierFlagCommand), cmdKey);
}

- (void)testConvertModifiersToCocoaModifiersIfNecessary
{
  SPTAssertEqual(SpectacleConvertModifiersToCocoaIfNecessary(NSEventModifierFlagControl), NSEventModifierFlagControl);
  SPTAssertEqual(SpectacleConvertModifiersToCocoaIfNecessary(NSEventModifierFlagOption), NSEventModifierFlagOption);
  SPTAssertEqual(SpectacleConvertModifiersToCocoaIfNecessary(NSEventModifierFlagShift), NSEventModifierFlagShift);
  SPTAssertEqual(SpectacleConvertModifiersToCocoaIfNecessary(NSEventModifierFlagCommand), NSEventModifierFlagCommand);
  SPTAssertEqual(SpectacleConvertModifiersToCocoaIfNecessary(controlKey), NSEventModifierFlagControl);
  SPTAssertEqual(SpectacleConvertModifiersToCocoaIfNecessary(optionKey), NSEventModifierFlagOption);
  SPTAssertEqual(SpectacleConvertModifiersToCocoaIfNecessary(shiftKey), NSEventModifierFlagShift);
  SPTAssertEqual(SpectacleConvertModifiersToCocoaIfNecessary(cmdKey), NSEventModifierFlagCommand);
}

@end


static SpectacleShortcut *shortcutForKeyBinding(NSString *keyBinding)
{
  return [[SpectacleShortcut alloc] initWithShortcutName:nil shortcutKeyBinding:keyBinding];
}

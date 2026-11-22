#import "SpectacleTestSupport.h"
#import <Carbon/Carbon.h>

#import "SpectacleShortcut.h"
#import "SpectacleShortcutKeyBindings.h"

static SpectacleShortcut *shortcutForKeyBinding(NSString *keyBinding);

@interface SpectacleShortcutKeyBindingsTests : XCTestCase
@end

@implementation SpectacleShortcutKeyBindingsTests

- (void)testConvertAnEmptyOrNilKeyBindingToNilModifiers
{
  XCTAssertNil(SpectacleConvertShortcutKeyBindingToModifiers(nil));
  XCTAssertNil(SpectacleConvertShortcutKeyBindingToModifiers(@""));
  XCTAssertNil(SpectacleConvertShortcutKeyBindingToModifiers(@" "));
}

- (void)testConvertKeyBindingsToModifiers
{
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToModifiers(@"cmd+c"), cmdKey);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToModifiers(@"shift+cmd+c"), shiftKey |cmdKey);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToModifiers(@"alt+shift+cmd+c"), optionKey | shiftKey |cmdKey);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToModifiers(@"ctrl+alt+shift+cmd+c"), controlKey | optionKey | shiftKey | cmdKey);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToModifiers(@"command+c"), cmdKey);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToModifiers(@"shift+command+c"), shiftKey |cmdKey);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToModifiers(@"option+shift+command+c"), optionKey | shiftKey |cmdKey);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToModifiers(@"control+option+shift+command+c"), controlKey | optionKey | shiftKey | cmdKey);
}

- (void)testConvertMixedCaseKeyBindingsToModifiers
{
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToModifiers(@"Cmd+C"), cmdKey);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToModifiers(@"Shift+Cmd+C"), shiftKey |cmdKey);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToModifiers(@"Alt+Shift+Cmd+C"), optionKey | shiftKey |cmdKey);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToModifiers(@"Ctrl+Alt+Shift+Cmd+C"), controlKey | optionKey | shiftKey | cmdKey);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToModifiers(@"COMMAND+C"), cmdKey);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToModifiers(@"SHIFT+COMMAND+C"), shiftKey |cmdKey);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToModifiers(@"OPTION+SHIFT+COMMAND+C"), optionKey | shiftKey |cmdKey);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToModifiers(@"CONTROL+OPTION+SHIFT+COMMAND+C"), controlKey | optionKey | shiftKey | cmdKey);
}

- (void)testConvertKeyBindingsWithWhitespaceToModifiers
{
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToModifiers(@" alt  +   shift    +     cmd    +c"), optionKey | shiftKey |cmdKey);
}

- (void)testConvertAnEmptyOrNilKeyBindingToNilKeyCodes
{
  XCTAssertNil(SpectacleConvertShortcutKeyBindingToKeyCode(nil));
  XCTAssertNil(SpectacleConvertShortcutKeyBindingToKeyCode(@""));
  XCTAssertNil(SpectacleConvertShortcutKeyBindingToKeyCode(@" "));
}

- (void)testConvertLowercaseAlphabeticalKeyBindingsToKeyCodes
{
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"a"), kVK_ANSI_A);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"b"), kVK_ANSI_B);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"c"), kVK_ANSI_C);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"d"), kVK_ANSI_D);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"e"), kVK_ANSI_E);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"f"), kVK_ANSI_F);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"g"), kVK_ANSI_G);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"h"), kVK_ANSI_H);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"i"), kVK_ANSI_I);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"j"), kVK_ANSI_J);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"k"), kVK_ANSI_K);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"l"), kVK_ANSI_L);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"m"), kVK_ANSI_M);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"n"), kVK_ANSI_N);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"o"), kVK_ANSI_O);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"p"), kVK_ANSI_P);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"q"), kVK_ANSI_Q);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"r"), kVK_ANSI_R);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"s"), kVK_ANSI_S);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"t"), kVK_ANSI_T);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"u"), kVK_ANSI_U);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"v"), kVK_ANSI_V);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"w"), kVK_ANSI_W);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"x"), kVK_ANSI_X);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"y"), kVK_ANSI_Y);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"z"), kVK_ANSI_Z);
}

- (void)testConvertUppercaseAlphabeticalKeyBindingsToKeyCodes
{
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"A"), kVK_ANSI_A);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"B"), kVK_ANSI_B);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"C"), kVK_ANSI_C);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"D"), kVK_ANSI_D);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"E"), kVK_ANSI_E);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"F"), kVK_ANSI_F);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"G"), kVK_ANSI_G);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"H"), kVK_ANSI_H);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"I"), kVK_ANSI_I);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"J"), kVK_ANSI_J);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"K"), kVK_ANSI_K);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"L"), kVK_ANSI_L);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"M"), kVK_ANSI_M);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"N"), kVK_ANSI_N);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"O"), kVK_ANSI_O);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"P"), kVK_ANSI_P);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Q"), kVK_ANSI_Q);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"R"), kVK_ANSI_R);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"S"), kVK_ANSI_S);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"T"), kVK_ANSI_T);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"U"), kVK_ANSI_U);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"V"), kVK_ANSI_V);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"W"), kVK_ANSI_W);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"X"), kVK_ANSI_X);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Y"), kVK_ANSI_Y);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Z"), kVK_ANSI_Z);
}

- (void)testConvertNumericKeyBindingsToKeyCodes
{
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"0"), kVK_ANSI_0);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"1"), kVK_ANSI_1);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"2"), kVK_ANSI_2);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"3"), kVK_ANSI_3);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"4"), kVK_ANSI_4);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"5"), kVK_ANSI_5);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"6"), kVK_ANSI_6);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"7"), kVK_ANSI_7);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"8"), kVK_ANSI_8);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"9"), kVK_ANSI_9);
}

- (void)testConvertAlphabeticalKeyBindingsWithModifiersToKeyCodes
{
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"cmd+a"), kVK_ANSI_A);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"shift+cmd+b"), kVK_ANSI_B);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"alt+shift+cmd+c"), kVK_ANSI_C);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"ctrl+alt+shift+cmd+d"), kVK_ANSI_D);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"command+e"), kVK_ANSI_E);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"shift+command+f"), kVK_ANSI_F);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"option+shift+command+g"), kVK_ANSI_G);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"control+option+shift+command+h"), kVK_ANSI_H);
}

- (void)testConvertAlphanumericKeyBindingsWithWhitespaceToKeyCodes
{
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@" cmd  +   a    "), kVK_ANSI_A);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@" shift  +   cmd    +     0      "), kVK_ANSI_0);
}

- (void)testConvertNamedKeyBindingsToKeyCodes
{
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"f1"), kVK_F1);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"f2"), kVK_F2);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"f3"), kVK_F3);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"f4"), kVK_F4);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"f5"), kVK_F5);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"f6"), kVK_F6);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"f7"), kVK_F7);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"f8"), kVK_F8);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"f9"), kVK_F9);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"f10"), kVK_F10);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"f11"), kVK_F11);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"f12"), kVK_F12);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"f13"), kVK_F13);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"f14"), kVK_F14);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"f15"), kVK_F15);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"f16"), kVK_F16);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"f17"), kVK_F17);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"f18"), kVK_F18);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"f19"), kVK_F19);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"f20"), kVK_F20);

  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"keypaddecimal"), kVK_ANSI_KeypadDecimal);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"keypadmultiply"), kVK_ANSI_KeypadMultiply);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"keypadplus"), kVK_ANSI_KeypadPlus);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"keypadclear"), kVK_ANSI_KeypadClear);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"keypaddivide"), kVK_ANSI_KeypadDivide);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"keypadenter"), kVK_ANSI_KeypadEnter);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"keypadminus"), kVK_ANSI_KeypadMinus);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"keypadequals"), kVK_ANSI_KeypadEquals);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"keypad0"), kVK_ANSI_Keypad0);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"keypad1"), kVK_ANSI_Keypad1);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"keypad2"), kVK_ANSI_Keypad2);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"keypad3"), kVK_ANSI_Keypad3);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"keypad4"), kVK_ANSI_Keypad4);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"keypad5"), kVK_ANSI_Keypad5);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"keypad6"), kVK_ANSI_Keypad6);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"keypad7"), kVK_ANSI_Keypad7);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"keypad8"), kVK_ANSI_Keypad8);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"keypad9"), kVK_ANSI_Keypad9);

  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"return"), kVK_Return);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"tab"), kVK_Tab);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"space"), kVK_Space);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"delete"), kVK_Delete);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"escape"), kVK_Escape);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"command"), kVK_Command);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"shift"), kVK_Shift);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"capslock"), kVK_CapsLock);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"option"), kVK_Option);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"control"), kVK_Control);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"rightshift"), kVK_RightShift);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"rightoption"), kVK_RightOption);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"rightcontrol"), kVK_RightControl);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"function"), kVK_Function);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"volumeup"), kVK_VolumeUp);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"volumedown"), kVK_VolumeDown);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"mute"), kVK_Mute);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"help"), kVK_Help);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"home"), kVK_Home);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"pageup"), kVK_PageUp);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"forwarddelete"), kVK_ForwardDelete);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"end"), kVK_End);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"pagedown"), kVK_PageDown);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"left"), kVK_LeftArrow);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"right"), kVK_RightArrow);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"down"), kVK_DownArrow);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"up"), kVK_UpArrow);
}

- (void)testConvertMixedCaseNamedKeyBindingsToKeyCodes
{
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"F1"), kVK_F1);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"F2"), kVK_F2);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"F3"), kVK_F3);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"F4"), kVK_F4);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"F5"), kVK_F5);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"F6"), kVK_F6);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"F7"), kVK_F7);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"F8"), kVK_F8);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"F9"), kVK_F9);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"F10"), kVK_F10);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"F11"), kVK_F11);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"F12"), kVK_F12);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"F13"), kVK_F13);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"F14"), kVK_F14);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"F15"), kVK_F15);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"F16"), kVK_F16);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"F17"), kVK_F17);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"F18"), kVK_F18);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"F19"), kVK_F19);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"F20"), kVK_F20);

  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"KeypadDecimal"), kVK_ANSI_KeypadDecimal);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"KeypadMultiply"), kVK_ANSI_KeypadMultiply);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"KeypadPlus"), kVK_ANSI_KeypadPlus);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"KeypadClear"), kVK_ANSI_KeypadClear);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"KeypadDivide"), kVK_ANSI_KeypadDivide);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"KeypadEnter"), kVK_ANSI_KeypadEnter);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"KeypadMinus"), kVK_ANSI_KeypadMinus);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"KeypadEquals"), kVK_ANSI_KeypadEquals);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Keypad0"), kVK_ANSI_Keypad0);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Keypad1"), kVK_ANSI_Keypad1);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Keypad2"), kVK_ANSI_Keypad2);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Keypad3"), kVK_ANSI_Keypad3);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Keypad4"), kVK_ANSI_Keypad4);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Keypad5"), kVK_ANSI_Keypad5);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Keypad6"), kVK_ANSI_Keypad6);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Keypad7"), kVK_ANSI_Keypad7);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Keypad8"), kVK_ANSI_Keypad8);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Keypad9"), kVK_ANSI_Keypad9);

  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Return"), kVK_Return);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Tab"), kVK_Tab);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Space"), kVK_Space);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Delete"), kVK_Delete);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Escape"), kVK_Escape);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Command"), kVK_Command);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Shift"), kVK_Shift);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"CapsLock"), kVK_CapsLock);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Option"), kVK_Option);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Control"), kVK_Control);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"RightShift"), kVK_RightShift);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"RightOption"), kVK_RightOption);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"RightControl"), kVK_RightControl);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Function"), kVK_Function);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"VolumeUp"), kVK_VolumeUp);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"VolumeDown"), kVK_VolumeDown);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Mute"), kVK_Mute);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Help"), kVK_Help);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Home"), kVK_Home);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"PageUp"), kVK_PageUp);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"ForwardDelete"), kVK_ForwardDelete);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"End"), kVK_End);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"PageDown"), kVK_PageDown);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Left"), kVK_LeftArrow);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Right"), kVK_RightArrow);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Down"), kVK_DownArrow);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"Up"), kVK_UpArrow);
}

- (void)testConvertNamedKeyBindingsWithModifiersToKeyCodes
{
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"cmd+up"), kVK_UpArrow);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"shift+cmd+down"), kVK_DownArrow);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"alt+shift+cmd+left"), kVK_LeftArrow);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"ctrl+alt+shift+cmd+right"), kVK_RightArrow);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"command+space"), kVK_Space);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"shift+command+f1"), kVK_F1);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"option+shift+command+keypad0"), kVK_ANSI_Keypad0);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"control+option+shift+command+escape"), kVK_Escape);
}

- (void)testConvertMixedCaseNamedKeyBindingsWithModifiersToKeyCodes
{
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"cmd+Up"), kVK_UpArrow);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"shift+cmd+Down"), kVK_DownArrow);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"alt+shift+cmd+left"), kVK_LeftArrow);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"ctrl+alt+shift+cmd+Right"), kVK_RightArrow);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"command+SPACE"), kVK_Space);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"shift+command+F1"), kVK_F1);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"option+shift+command+KEYPAD0"), kVK_ANSI_Keypad0);
  SPTAssertEqual(SpectacleConvertShortcutKeyBindingToKeyCode(@"control+option+shift+command+ESCAPE"), kVK_Escape);
}

- (void)testConvertEmptyShortcutsToNilKeyBindings
{
  XCTAssertNil(SpectacleConvertShortcutToKeyBinding(shortcutForKeyBinding(nil)));
}

- (void)testConvertShortcutsToKeyBindings
{
  SPTAssertEqual(SpectacleConvertShortcutToKeyBinding(shortcutForKeyBinding(@"alt+cmd+c")), @"alt+cmd+c");
  SPTAssertEqual(SpectacleConvertShortcutToKeyBinding(shortcutForKeyBinding(@"alt+cmd+f")), @"alt+cmd+f");
  SPTAssertEqual(SpectacleConvertShortcutToKeyBinding(shortcutForKeyBinding(@"alt+cmd+left")), @"alt+cmd+left");
  SPTAssertEqual(SpectacleConvertShortcutToKeyBinding(shortcutForKeyBinding(@"alt+cmd+right")), @"alt+cmd+right");
  SPTAssertEqual(SpectacleConvertShortcutToKeyBinding(shortcutForKeyBinding(@"alt+cmd+up")), @"alt+cmd+up");
  SPTAssertEqual(SpectacleConvertShortcutToKeyBinding(shortcutForKeyBinding(@"alt+cmd+down")), @"alt+cmd+down");
  SPTAssertEqual(SpectacleConvertShortcutToKeyBinding(shortcutForKeyBinding(@"ctrl+cmd+left")), @"ctrl+cmd+left");
  SPTAssertEqual(SpectacleConvertShortcutToKeyBinding(shortcutForKeyBinding(@"ctrl+shift+cmd+left")), @"ctrl+shift+cmd+left");
  SPTAssertEqual(SpectacleConvertShortcutToKeyBinding(shortcutForKeyBinding(@"ctrl+cmd+right")), @"ctrl+cmd+right");
  SPTAssertEqual(SpectacleConvertShortcutToKeyBinding(shortcutForKeyBinding(@"ctrl+shift+cmd+right")), @"ctrl+shift+cmd+right");
  SPTAssertEqual(SpectacleConvertShortcutToKeyBinding(shortcutForKeyBinding(@"ctrl+alt+cmd+right")), @"ctrl+alt+cmd+right");
  SPTAssertEqual(SpectacleConvertShortcutToKeyBinding(shortcutForKeyBinding(@"ctrl+alt+cmd+left")), @"ctrl+alt+cmd+left");
  SPTAssertEqual(SpectacleConvertShortcutToKeyBinding(shortcutForKeyBinding(@"ctrl+alt+right")), @"ctrl+alt+right");
  SPTAssertEqual(SpectacleConvertShortcutToKeyBinding(shortcutForKeyBinding(@"ctrl+alt+left")), @"ctrl+alt+left");
  SPTAssertEqual(SpectacleConvertShortcutToKeyBinding(shortcutForKeyBinding(@"ctrl+alt+shift+right")), @"ctrl+alt+shift+right");
  SPTAssertEqual(SpectacleConvertShortcutToKeyBinding(shortcutForKeyBinding(@"ctrl+alt+shift+left")), @"ctrl+alt+shift+left");
  SPTAssertEqual(SpectacleConvertShortcutToKeyBinding(shortcutForKeyBinding(@"alt+cmd+z")), @"alt+cmd+z");
  SPTAssertEqual(SpectacleConvertShortcutToKeyBinding(shortcutForKeyBinding(@"alt+shift+cmd+z")), @"alt+shift+cmd+z");
}

@end


static SpectacleShortcut *shortcutForKeyBinding(NSString *keyBinding)
{
  return [[SpectacleShortcut alloc] initWithShortcutName:nil shortcutKeyBinding:keyBinding];
}

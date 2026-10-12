package mod;

import funkin.ui.MusicBeatSubState;
import funkin.save.Save;
import flixel.FlxCamera;
import funkin.ui.AtlasText;
import flixel.text.FlxText;
import funkin.graphics.FunkinSprite;
import flixel.FlxObject;
import flixel.FlxSprite;
import funkin.ui.TextMenuList;
import funkin.graphics.FunkinCamera;
import flixel.math.FlxPoint;
import flixel.FlxG;
import funkin.Paths;
import funkin.audio.FunkinSound;

class RebindSubState extends MusicBeatSubState
{
  var items:TextMenuList;
  var activeRemap:String = "";
  var menuCam = new FunkinCamera("");

  var keysFrendlyNames:Map<Int, String> = [
    65 => "A",
    66 => "B",
    67 => "C",
    68 => "D",
    69 => "E",
    70 => "F",
    71 => "G",
    72 => "H",
    73 => "I",
    74 => "J",
    75 => "K",
    76 => "L",
    77 => "M",
    78 => "N",
    79 => "O",
    80 => "P",
    81 => "Q",
    82 => "R",
    83 => "S",
    84 => "T",
    85 => "U",
    86 => "V",
    87 => "W",
    88 => "X",
    89 => "Y",
    90 => "Z",
    48 => "ZERO",
    49 => "ONE",
    50 => "TWO",
    51 => "THREE",
    52 => "FOUR",
    53 => "FIVE",
    54 => "SIX",
    55 => "SEVEN",
    56 => "EIGHT",
    57 => "NINE",
    33 => "PAGEUP",
    34 => "PAGEDOWN",
    36 => "HOME",
    35 => "END",
    45 => "INSERT",
    27 => "ESCAPE",
    189 => "MINUS",
    187 => "PLUS",
    46 => "DELETE",
    8 => "BACKSPACE",
    219 => "LBRACKET",
    221 => "RBRACKET",
    220 => "BACKSLASH",
    20 => "CAPSLOCK",
    145 => "SCROLL_LOCK",
    144 => "NUMLOCK",
    186 => "SEMICOLON",
    222 => "QUOTE",
    13 => "ENTER",
    16 => "SHIFT",
    188 => "COMMA",
    190 => "PERIOD",
    191 => "SLASH",
    192 => "GRAVEACCENT",
    17 => "CONTROL",
    18 => "ALT",
    32 => "SPACE",
    38 => "UP",
    40 => "DOWN",
    37 => "LEFT",
    39 => "RIGHT",
    9 => "TAB",
    15 => "WINDOWS",
    302 => "MENU",
    301 => "PRINTSCREEN",
    19 => "BREAK",
    112 => "F1",
    113 => "F2",
    114 => "F3",
    115 => "F4",
    116 => "F5",
    117 => "F6",
    118 => "F7",
    119 => "F8",
    120 => "F9",
    121 => "F10",
    122 => "F11",
    123 => "F12",
    96 => "NUM_ZERO",
    97 => "NUM_ONE",
    98 => "NUM_TWO",
    99 => "NUM_THREE",
    100 => "NUM_FOUR",
    101 => "NUM_FIVE",
    102 => "NUM_SIX",
    103 => "NUM_SEVEN",
    104 => "NUM_EIGHT",
    105 => "NUM_NINE",
    109 => "NUM_MINUS",
    107 => "NUM_PLUS",
    110 => "NUM_PERIOD",
    106 => "NUM_MULTIPLY",
    111 => "NUM_SLASH"
  ];

  /**
   * Camera focus point
   */
  var camFocusPoint:FlxObject;

  var cardFade:FunkinSprite;
  var cardFront:FunkinSprite;
  var cardText:AtlasText;

  public function new()
  {
    super();
  }

  override function create():Void
  {
    FlxG.cameras.add(menuCam);
    super.create();

    bgColor = 0x00000000;

    // Create an object for the camera to track.
    camFocusPoint = new FlxObject(0, 0);
    camFocusPoint.camera = menuCam;
    add(camFocusPoint);

    // Follow the camera focus as we scroll.
    menuCam.follow(camFocusPoint, null, 0.06);

    cardFade = new FunkinSprite(0, 0);
    cardFade.makeSolidColor(FlxG.width, FlxG.height, 0x48000000);
    cardFade.updateHitbox();
    cardFade.screenCenter();
    cardFade.scrollFactor.set(0, 0);
    cardFade.visible = false;

    cardFront = new FunkinSprite(0, 0);
    cardFront.makeSolidColor(850, 470, 0xFFB1DD10);
    cardFront.screenCenter();
    cardFront.scrollFactor.set(0, 0);
    cardFront.visible = false;

    cardText = new AtlasText("", "bold");
    cardText.screenCenter();
    cardText.scrollFactor.set(0, 0);
    cardText.visible = false;

    // Create the purble background.
    var menuBG = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
    menuBG.color = 0xFF6C11B6;
    menuBG.setGraphicSize(Std.int(menuBG.width * 1.1));
    menuBG.updateHitbox();
    menuBG.screenCenter();
    menuBG.scrollFactor.set(0, 0);

    // Create the list for menu items.
    items = new TextMenuList();
    items.camera = menuCam;
    // Move the camera when the menu is scrolled.
    items.onChange.add(onMenuChange);

    add(menuBG);
    add(items);
    add(cardFade);
    add(cardFront);
    add(cardText);

    // Create each menu item.
    // Call onMenuChange when the first item is created to move the camera .
    onMenuChange(createItem("Remap Keyboard Index reset", () -> startRemapingKey("keyboard_IndexReset")));
    createItem("Remap Keyboard Index hold", () -> startRemapingKey("keyboard_IndexHold"));

    menuCam.focusOn(new FlxPoint(camFocusPoint.x, camFocusPoint.y + 500));
  }

  function onMenuChange(selected:TextMenuItem)
  {
    camFocusPoint.setPosition(selected.x + selected.width / 2, selected.y + selected.height / 2);
  }

  override function update(elapsed:Float)
  {
    super.update(elapsed);
    if (activeRemap != "")
    {
      pullKey();
    }
    else if (controls.BACK)
    {
      FunkinSound.playOnce(Paths.sound('cancelMenu'));
      exitDebugMenu();
    }
  }

  function createItem(name:String, callback:Void->Void, fireInstantly = false)
  {
    var item = items.createItem(0, 100 + items.length * 100, name, "bold", callback);
    item.fireInstantly = fireInstantly;
    item.screenCenter(X);
    return item;
  }

  function startRemapingKey(key:String)
  {
    activeRemap = key;
    items.active = false;

    cardFade.visible = true;
    cardFront.visible = true;

    var bindCode = 0;
    switch (activeRemap)
    {
      case "keyboard_IndexReset":
        bindCode = Save.instance.modOptions.get("keyboard_indexReset");
      case "keyboard_IndexHold":
        bindCode = Save.instance.modOptions.get("keyboard_indexHold");
    }

    var promptTxt = "\nPress any key to rebind\n";
    if (keysFrendlyNames.exists(bindCode))
    {
      promptTxt += "Current bind: " + keysFrendlyNames[bindCode];
    }
    promptTxt += "\n\n\n  Backspace to unbind\n   Escape to cancel";

    cardText.text = promptTxt;
    cardText.screenCenter();
    cardText.y -= 300;
    cardText.x -= 390;
    cardText.updateHitbox();
    cardText.visible = true;
  }

  function pullKey()
  {
    var NONE:Int = -1;

    var key = FlxG.keys.firstJustPressed();
    if (key != NONE)
    {
      if (key == 27)
      {
        FunkinSound.playOnce(Paths.sound('cancelMenu'));
        closePrompt();
      }
      else if (key == 8)
      {
        FunkinSound.playOnce(Paths.sound('keyErase'));
        onInputSelect(NONE);
        closePrompt();
      }
      else
      {
        FunkinSound.playOnce(Paths.sound('confirmMenu'));
        onInputSelect(key);
        closePrompt();
      }
    }
  }

  function onInputSelect(key:Int)
  {
    switch (activeRemap)
    {
      case "keyboard_IndexReset":
        Save.instance.modOptions.set("keyboard_indexReset", key);
      case "keyboard_IndexHold":
        Save.instance.modOptions.set("keyboard_indexHold", key);
    }
  }

  function closePrompt()
  {
    activeRemap = "";
    items.active = true;
    cardFade.visible = false;
    cardFront.visible = false;
    cardText.visible = false;
  }

  function exitDebugMenu()
  {
    menuCam.destroy();
    this.close();
  }
}

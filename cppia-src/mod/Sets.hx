package mod;

import funkin.util.ReflectUtil;
import mod.RebindSubState;
import funkin.save.Save;
import flixel.FlxState;
import funkin.ui.Prompt;
import flixel.FlxG;
import funkin.modding.events.ScriptEvent;
import funkin.ui.options.PreferencesMenu;
import funkin.ui.options.OptionsState;
import funkin.modding.module.Module;

class Sets extends Module
{
  var prompt:Prompt;
  var remap:String = "";

  override function onCreate(event:ScriptEvent)
  {
    if (!Save.instance.modOptions.exists("parappaToggle")) Save.instance.modOptions.set("parappaToggle", true);
    if (!Save.instance.modOptions.exists("coolMode")) Save.instance.modOptions.set("coolMode", true);
    if (!Save.instance.modOptions.exists("noteHit")) Save.instance.modOptions.set("noteHit", false);
    if (!Save.instance.modOptions.exists("ReqGoodRank")) Save.instance.modOptions.set("ReqGoodRank", true);
    if (!Save.instance.modOptions.exists(" freestyleJudge ")) Save.instance.modOptions.set("freestyleJudge", true);
    if (!Save.instance.modOptions.exists("BreakGrading")) Save.instance.modOptions.set("BreakGrading", true);

    if (!Save.instance.modOptions.exists("keyboard_indexReset")) Save.instance.modOptions.set("keyboard_indexReset", 75); // FlxKey.K;
    if (!Save.instance.modOptions.exists("keyboard_indexHold")) Save.instance.modOptions.set("keyboard_indexHold", 74); // FlxKey.J;

    super.onCreate(event);
  }

  override function onStateChangeEnd(ev:StateChangeScriptEvent)
  {
    super.onStateChangeEnd(ev);
    var state = ev.targetState;

    if (Std.isOfType(state, OptionsState))
    {
      var curState:OptionsState = cast ev.targetState;
      var mainPage:OptionsMenu = cast curState.optionsCodex.currentPage;
      if (!FlxG.onMobile)
      {
        mainPage.items.resetItem("EXIT", "freestyle keybinds", function() {
          var subState = new RebindSubState();
          subState.closeCallback = () -> {
            mainPage.canExit = true;
            mainPage.items.active = true;
          }
          curState.openSubState(subState);
          mainPage.items.active = false;
          mainPage.canExit = false;
        });
        mainPage.items.byName["freestyle keybinds"].screenCenter(X);

        mainPage.createItem("EXIT", function() {
          mainPage.exit();
        });
      }

      var controls:PreferencesMenu = cast curState.optionsCodex.pages.get(Preferences); // this breaks on versions older than 0.4.1
      var tmp:PreferencesMenu = cast curState.optionsCodex.pages.get(Preferences); // this breaks on versions older than 0.4.1

      tmp.createPrefItemCheckbox("PaRappa scoring", "If unchecked, disables the PaRappa scoring system.", b -> {
        Save.instance.modOptions.set("parappaToggle", b);
      }, Save.instance.modOptions.get("parappaToggle"));

      tmp.createPrefItemCheckbox("Cool mode + freestyle", "If checked, lets you ghost tap your way to the Cool mode!", b -> {
        Save.instance.modOptions.set("coolMode", b);
      }, Save.instance.modOptions.get("coolMode"));

      tmp.createPrefItemCheckbox("freestyle judgements", "Shows the judgements for your freestyle presses.", b -> {
        Save.instance.modOptions.set("freestyleJudge", b);
      }, Save.instance.modOptions.get("freestyleJudge"));

      tmp.createPrefItemCheckbox("Require \"good\" to pass", "", b -> {
        Save.instance.modOptions.set("ReqGoodRank", b);
      }, Save.instance.modOptions.get("ReqGoodRank"));

      tmp.createPrefItemCheckbox("Auditory Feedback", "Enables some old hitsounds. Not sure why we need that though.", b -> {
        Save.instance.modOptions.set("noteHit", b);
      }, Save.instance.modOptions.get("noteHit"));

      tmp.createPrefItemCheckbox("Break based grading", "", b -> {
        Save.instance.modOptions.set("BreakGrading", b);
      }, Save.instance.modOptions.get("BreakGrading"));
    }
  }
}

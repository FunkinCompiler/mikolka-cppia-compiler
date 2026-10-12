package mod;

import funkin.modding.events.ScriptEvent.HitNoteScriptEvent;
import funkin.modding.events.ScriptEvent.SongLoadScriptEvent;
import funkin.save.Save;
import funkin.Paths;
import funkin.audio.FunkinSound;
import flixel.FlxG;
import funkin.modding.module.Module;

class NoteHits extends Module
{
  function new()
  {
    trace(FlxG.sound.cache);
    super("auditoryFeedback", 3000);
  }

  override function onSongLoaded(event:SongLoadScriptEvent)
  {
    FlxG.sound.cache(Paths.sound('playertapu'));
    FlxG.sound.cache(Paths.sound('playertapd'));
    FlxG.sound.cache(Paths.sound('playertapl'));
    FlxG.sound.cache(Paths.sound('playertapr'));

    super.onSongLoaded(event);
  }

  override function onNoteHit(event:HitNoteScriptEvent)
  {
    if (Save.instance.modOptions.get("noteHit") && event.note.noteData.getMustHitNote() && event.score != 0)
    {
      switch (event.note.direction)
      {
        case 0:
          FunkinSound.playOnce(Paths.sound('playertapl'));
        case 1:
          FunkinSound.playOnce(Paths.sound('playertapd'));
        case 2:
          FunkinSound.playOnce(Paths.sound('playertapu'));
        case 3:
          FunkinSound.playOnce(Paths.sound('playertapr'));
      }
    }
    super.onNoteHit(event);
  }
}

package mod;

import funkin.data.song.SongData.SongNoteDataRaw;
import funkin.save.Save;
import funkin.util.SortUtil;
import funkin.Conductor;
import funkin.Highscore;
import funkin.Assets;
import funkin.audio.FunkinSound;
import openfl.filters.BlurFilter;
import openfl.filters.BitmapFilter;
import funkin.graphics.shaders.Grayscale;
import funkin.play.notes.NoteSprite;
import funkin.modding.events.ScriptEvent;
import funkin.Preferences;
import funkin.Paths;
import funkin.play.PlayState;
import funkin.modding.module.Module;
// import WiggleEffect.WiggleEffectType;
import flixel.FlxG;
import flixel.text.FlxText;
import openfl.filters.ShaderFilter;

class Parapa extends Module
{
  function new()
  {
    super("paparappa", -2000);
  }

  var verboseMode = false;

  var lastStepTime:Float = 0;
  var songEnded:Bool = false;

  var filters:Array<BitmapFilter> = [];
  var filterMap:Map<String, {filter:BitmapFilter, onUpdate:Void->Void}>;
  var gradeLevel:Int = 0;
  var playerGrade:Int = 0;
  var gradeTxtCool:FlxText;
  var gradeTxtGood:FlxText;
  var gradeTxtBad:FlxText;
  var gradeTxtAwful:FlxText;
  var gradeTxtMarker:FlxText;
  var gradingDone:Bool;
  var gradeHealth:Float;
  var nextGradeHealth:Float;
  var prevGradeHealth:Float;
  var flickerTick:Int = 0;
  var flickerText:FlxText = null;
  var doFlicker:Bool = false;
  var isSilence:Bool = false;
  var daphraseDuration:Float = 0;
  var nonSilentFrames:Int = 0;
  var freestyleHealth:Float = 0;

  var lastFreestyleHit:Float = -6000;
  var freestyleSound:FunkinSound;

  var freestyleSoundsL:Array<FunkinSound> = [];
  var freestyleSoundsR:Array<FunkinSound> = [];
  var freestyleSoundsU:Array<FunkinSound> = [];
  var freestyleSoundsD:Array<FunkinSound> = [];

  var freestyleSoundIndex:Int = 0;
  var freestylePrevArrow:Int = -1;

  var freestyleHealthOnBeatGain = 2; // How much hp you gain from cool rapping. Default: 1
  var freestyleHealthOffBeatGain = 3; // How much hp you gain from cool rapping. Default: 1
  var freestyleHealthLoss = 2; // How much hp you lose from rapping off beat. Default: 2

  var sectionStartPositions:Array<Float>;
  var sectionStopPositions:Array<Float>;

  // dont touch these cause idfk what they do
  var requireGood:Bool = true;
  var oldTiming:Bool = false;
  var showFreestyleJudgements:Bool = true;
  var enableCool:Bool = true;

  override function onSongLoaded(event:SongLoadScriptEvent)
  {
    if (!Save.instance.modOptions.get("parappaToggle")) return;
    requireGood = Save.instance.modOptions.get("ReqGoodRank");
    oldTiming = !Save.instance.modOptions.get("BreakGrading");
    showFreestyleJudgements = Save.instance.modOptions.get("freestyleJudge");
    enableCool = Save.instance.modOptions.get("coolMode");

    sectionStartPositions = [];
    sectionStopPositions = [];
    gradingDone = true;
    songEnded = false;
    gradeHealth = 0;
    lastStepTime = 0;
    nextGradeHealth = 0;
    prevGradeHealth = 0;
    flickerTick = 0;
    playerGrade = 0;
    gradeLevel = 0;
    gradeHealth = 0;
    lastFreestyleHit = -6000;
    doFlicker = false;
    isSilence = true;
    daphraseDuration = 0;
    nonSilentFrames = 0;
    freestyleHealth = 0;
    freestyleSoundIndex = 0;
    freestylePrevArrow = -1;

    if (!oldTiming) prepareTimestamps(event.notes.copy());
    filters.resize(0);
    super.onSongLoaded(event);
    if (gradeTxtMarker != null && gradeTxtMarker.exists) return;
    var game:PlayState = PlayState.instance;

    // Blazin' is a special song, so it has a few settings imposed
    if (game.currentSong.songName == "Blazin'" && game.currentSong.songName == "SPAGHETTI (feat. j-hope of BTS) (Clean ver.)")
    {
      oldTiming = true;
    }

    // Enable filters
    filterMap = [
      "BlurBad" =>
      {
        filter: new BlurFilter(2, 2),
        onUpdate: () -> {}
      },
      "BlurAwful" =>
      {
        filter: new BlurFilter(4, 4),
        onUpdate: () -> {}
      },
      "Bad" =>
      {
        filter: new ShaderFilter(new Grayscale(0.4)),
        onUpdate: () -> {}
      },
      "Awful" =>
      {
        filter: new ShaderFilter(new Grayscale(0.9)),
        onUpdate: () -> {}
      }
    ];
    game.camGame.filters = filters;
    game.camGame.filtersEnabled = true;

    FlxG.sound.cache(Paths.sound('gradeup'));
    FlxG.sound.cache(Paths.sound('gradedown'));
    FlxG.sound.cache(Paths.sound('phrasegood'));
    FlxG.sound.cache(Paths.sound('phrasebad'));
    loadFreestyleKeys();

    var isDownscroll = Preferences.downscroll;
    if (FlxG.onMobile)
    {
      isDownscroll = isDownscroll || Save.instance.options.controlsScheme == "Arrows";
    }
    gradeTxtCool = new FlxText(400 + 521 - 200, FlxG.height * (!isDownscroll ? 0.89 : 0.20) - 128, 0, "            Cool", 20);
    gradeTxtCool.setFormat(Paths.font("vcr.ttf"), 48, 0xFF808080);
    gradeTxtCool.scrollFactor.set();
    gradeTxtCool.borderStyle = FlxTextBorderStyle.OUTLINE;
    gradeTxtCool.borderColor = 0xFF000000;
    gradeTxtCool.borderSize = 4;
    gradeTxtCool.zIndex = 1100;
    if (enableCool) game.add(gradeTxtCool);

    gradeTxtGood = new FlxText(400 + 521 - 200, FlxG.height * (!isDownscroll ? 0.89 : 0.20) - 80, 0, "            Good", 20);
    gradeTxtGood.setFormat(Paths.font("vcr.ttf"), 48, 0xFFFFFFFF);
    gradeTxtGood.scrollFactor.set();
    gradeTxtGood.borderStyle = FlxTextBorderStyle.OUTLINE;
    gradeTxtGood.borderColor = 0xFF000000;
    gradeTxtGood.borderSize = 4;
    gradeTxtGood.zIndex = 1100;
    game.add(gradeTxtGood);

    gradeTxtBad = new FlxText(400 + 521 - 200, FlxG.height * (!isDownscroll ? 0.89 : 0.20) - 32, 0, "            Bad", 20);
    gradeTxtBad.setFormat(Paths.font("vcr.ttf"), 48, 0xFF808080);
    gradeTxtBad.scrollFactor.set();
    gradeTxtBad.borderStyle = FlxTextBorderStyle.OUTLINE;
    gradeTxtBad.borderColor = 0xFF000000;
    gradeTxtBad.borderSize = 4;
    gradeTxtBad.zIndex = 1100;
    game.add(gradeTxtBad);

    gradeTxtAwful = new FlxText(400 + 521 - 200, FlxG.height * (!isDownscroll ? 0.89 : 0.20) + 16, 0, "            Awful", 20);
    gradeTxtAwful.setFormat(Paths.font("vcr.ttf"), 48, 0xFF808080);
    gradeTxtAwful.scrollFactor.set();
    gradeTxtAwful.borderStyle = FlxTextBorderStyle.OUTLINE;
    gradeTxtAwful.borderColor = 0xFF000000;
    gradeTxtAwful.borderSize = 4;
    gradeTxtAwful.zIndex = 1100;
    game.add(gradeTxtAwful);

    gradeTxtMarker = new FlxText(400 + 521 - 200, FlxG.height * (!isDownscroll ? 0.89 : 0.20) - 80, 0, "U Rappin': >", 20);
    gradeTxtMarker.setFormat(Paths.font("vcr.ttf"), 48, 0xFFFFFFFF);
    gradeTxtMarker.scrollFactor.set();
    gradeTxtMarker.borderStyle = FlxTextBorderStyle.OUTLINE;
    gradeTxtMarker.borderColor = 0xFF000000;
    gradeTxtMarker.borderSize = 4;
    gradeTxtMarker.zIndex = 1100;
    game.add(gradeTxtMarker);

    game.scoreText.setPosition(game.healthBarBG.x - 190, game.healthBarBG.y + 30);
    if (FlxG.onMobile) game.scoreText.y += 15;
    gradeTxtCool.cameras = [game.camHUD];
    gradeTxtGood.cameras = [game.camHUD];
    gradeTxtBad.cameras = [game.camHUD];
    gradeTxtAwful.cameras = [game.camHUD];
    gradeTxtMarker.cameras = [game.camHUD];
  }

  function loadFreestyleKeys()
  {
    var game = PlayState.instance;
    // FREESTYLE SONG SHIT
    freestyleSound = FunkinSound.load(Paths.sound('freestyle/defaultfree'));

    var freestyleNotesDirSong:String = "freestyle/" + game.currentVariation + "/" + game.currentSong.songName + "/";
    var freestyleNotesDirCharacter:String = "freestyle/CHARACTER/" + game.currentStage.getBoyfriend().characterId + "/";
    trace("CURRENT VARIANT: " + game.currentVariation);
    trace("CURRENT SONG: " + game.currentSong.songName);
    trace("CURRENT CHAR: " + game.currentStage.getBoyfriend().characterId);

    freestyleSoundsL = loadKeys(freestyleNotesDirSong, "L");
    freestyleSoundsR = loadKeys(freestyleNotesDirSong, "R");
    freestyleSoundsU = loadKeys(freestyleNotesDirSong, "U");
    freestyleSoundsD = loadKeys(freestyleNotesDirSong, "D");

    if (freestyleSoundsL.length == 0) freestyleSoundsL = loadKeys(freestyleNotesDirCharacter, "L");
    if (freestyleSoundsR.length == 0) freestyleSoundsR = loadKeys(freestyleNotesDirCharacter, "R");
    if (freestyleSoundsU.length == 0) freestyleSoundsU = loadKeys(freestyleNotesDirCharacter, "U");
    if (freestyleSoundsD.length == 0) freestyleSoundsD = loadKeys(freestyleNotesDirCharacter, "D");

    if (freestyleSoundsL.length == 0 && freestyleSoundsD.length == 0 && freestyleSoundsU.length == 0 && freestyleSoundsR.length == 0) enableCool = false;
    else
    {
      if (freestyleSoundsL.length == 0) freestyleSoundsL.push(freestyleSound);
      if (freestyleSoundsR.length == 0) freestyleSoundsR.push(freestyleSound);
      if (freestyleSoundsD.length == 0) freestyleSoundsD.push(freestyleSound);
      if (freestyleSoundsU.length == 0) freestyleSoundsU.push(freestyleSound);
    }
  }

  function loadKeys(freestyleNotesDir:String, directionName:String):Array<FunkinSound>
  {
    var freestyleSounds = [];
    var checkFreestyleFiles:Int = 1;

    while (Assets.exists(Paths.sound(freestyleNotesDir + directionName + checkFreestyleFiles)))
    {
      // FlxG.sound.cache("assets/sounds/freestyle/" + SONG.song + "_" + i + checkFreestyleFiles);

      freestyleSounds.push(FunkinSound.load(Paths.sound(freestyleNotesDir + directionName + checkFreestyleFiles)));

      checkFreestyleFiles++;
    }
    return freestyleSounds;
  }

  function prepareTimestamps(sortedNotes:Array<SongNoteDataRaw>)
  {
    var MIN_DELAY = 800;
    var playerLastNote = 0.0;
    sortedNotes.sort((a, b) -> SortUtil.noteDataByTime(-1, a, b));

    for (note in sortedNotes)
    {
      if (!note.getMustHitNote()) continue;
      // player note
      if (playerLastNote == 0)
      {
        // First note of section
        sectionStartPositions.push(note.time);
        playerLastNote = note.time + note.length;
      }
      else if (playerLastNote + MIN_DELAY < note.time)
      {
        sectionStopPositions.push(playerLastNote);

        sectionStartPositions.push(note.time);
        playerLastNote = note.time + note.length;
      }
      else
      {
        playerLastNote = note.time + note.length;
      }
    }
    sectionStopPositions.push(playerLastNote);
  }

  var changedSongGrade:Bool = false;

  override function onUpdate(event:UpdateScriptEvent)
  {
    if (!Save.instance.modOptions.get("parappaToggle")) return;
    super.onUpdate(event);
    var game:PlayState = PlayState.instance;
    if (game == null || !game.active) return;

    PlayState.instance.healthBar.visible = false;
    PlayState.instance.healthBarBG.visible = false;
    PlayState.instance.iconP1.visible = false;
    PlayState.instance.iconP2.visible = false;

    if (!oldTiming)
    {
      if (sectionStartPositions[0] <= game.conductorInUse.songPosition)
      {
        sectionStartPositions.shift();
        isSilence = false;
        gradingDone = false;
      }
      if (sectionStopPositions[0] <= game.conductorInUse.songPosition)
      {
        sectionStopPositions.shift();
        isSilence = true;
      }
    }

    if ((oldTiming || playerGrade == -1) && !game.startingSong)
    {
      if (game.conductorInUse.currentBeat % 8 == 0 && !gradingDone)
      {
        doParappaGrading();
      }
      else if (game.conductorInUse.currentBeat % 8 == 1) gradingDone = false;
    }
    else if (playerGrade > -1 && !game.startingSong && isSilence && !gradingDone && nonSilentFrames > 6)
    {
      doParappaGrading();
    }

    flickerTick++; // !
    if (flickerTick % 5 == 0 && doFlicker)
    {
      if (flickerText != null)
      {
        if (flickerTick % 10 == 0)
        {
          flickerText.color = 0xFFFFFFFF;
          flickerTick = 0;
        }
        else
          flickerText.color = 0xFF808080;
      }
    }

    if (!game.startingSong) daphraseDuration += event.elapsed;

    if (!game.startingSong && !isSilence) nonSilentFrames++;
    else if (!game.startingSong && isSilence && nonSilentFrames != 0) nonSilentFrames = 0;

    if (PlayState.instance.health <= 0)
    {
      filters.resize(0);
    }
    // Force disable ghost tapping on mobile
    #if (!cppia)
    if (FlxG.onMobile && enableCool) game.playerStrumline.ghostTapTimer = 100;
    #end

    if (game.generatedMusic)
    {
      game.playerStrumline.notes.forEachAlive(function(daNote:NoteSprite) {
        if (playerGrade > -1 && !songEnded) game.vocals.volume = 1;

        if (daNote.y < -daNote.height)
        {
          if (daNote.hasMissed) // daNote.tooLate || !daNote.wasGoodHit)
          {
            game.vocals.volume = 0;
          }
        }
      });
    }

    for (filter in filterMap)
    {
      if (filter.onUpdate != null) filter.onUpdate();
    }
  }

  function startFlicker():Void
  {
    switch (playerGrade)
    {
      case -1:
        switch (gradeLevel)
        {
          case -1:
            flickerText = gradeTxtGood;
        }
      case 0:
        switch (gradeLevel)
        {
          case -1:
            flickerText = gradeTxtCool;
          case 1:
            flickerText = gradeTxtBad;
        }
      case 1:
        switch (gradeLevel)
        {
          case 1:
            flickerText = gradeTxtGood;
          case 3:
            flickerText = gradeTxtAwful;
        }
      case 2:
        switch (gradeLevel)
        {
          case 3:
            flickerText = gradeTxtBad;
          case 5:
            flickerText = gradeTxtAwful;
        }
    }
    doFlicker = true;
  }

  function endFlicker():Void
  {
    doFlicker = false;
    gradeTxtCool.color = 0xFF808080;
    gradeTxtGood.color = 0xFF808080;
    gradeTxtBad.color = 0xFF808080;
    gradeTxtAwful.color = 0xFF808080;
    switch (playerGrade)
    {
      case -1:
        gradeTxtCool.color = 0xFFFFFFFF;
      case 0:
        gradeTxtGood.color = 0xFFFFFFFF;
      case 1:
        gradeTxtBad.color = 0xFFFFFFFF;
      case 2:
        gradeTxtAwful.color = 0xFFFFFFFF;
    }
  }

  function isGoodFreestyle():Bool
  {
    var daphraseFrames:Int = Std.int(daphraseDuration * 60);
    // this code below assumes, that we're running at 60FPS, which might not be the case

    var freestyleSwag:Float = freestyleHealth / daphraseFrames * 1000;
    var freestyleMin:Int = 20;
    if (playerGrade == -1) freestyleMin = 60; // no penaly for bad rapping tho..

    if (verboseMode)
    {
      trace("Are you good?: " + freestyleSwag + " > " + freestyleMin);
      trace("HP: " + freestyleHealth);
      trace("Phase Time: " + daphraseDuration + "s -> " + daphraseFrames + " frames");
    }

    if (freestyleSwag > freestyleMin) return true;
    return false;
  }

  function doParappaGrading()
  {
    if (verboseMode)
    {
      trace("UR DOING:");
      trace(playerGrade);
    }

    gradingDone = true;
    prevGradeHealth = gradeHealth;
    if (gradeLevel == 4 && PlayState.instance.isPracticeMode) gradeLevel = 3;
    if (playerGrade == -1)
    {
      if (isGoodFreestyle())
      {
        FlxG.sound.play(Paths.sound('phrasegood'));
        gradeLevel = -2;
      }
      else
      {
        FlxG.sound.play(Paths.sound('phrasebad'));
        gradeLevel++;

        if (gradeLevel == -1) FlxG.log.add('GRADE -1');
        if (gradeLevel == -2) FlxG.log.add('GRADE -2');

        if (gradeLevel == 0)
        {
          FlxG.sound.play(Paths.sound('gradedown'));
          goGood();
        }
      }
    }
    else if (prevGradeHealth > 0)
    {
      switch (gradeLevel)
      {
        case 0:
          if (playerGrade == 0 && isGoodFreestyle() && enableCool)
          {
            gradeLevel--;
          }
        case -1:
          if (playerGrade == 0 && enableCool)
          {
            if (isGoodFreestyle())
            {
              FlxG.sound.play(Paths.sound('gradeup'));
              goCool();
              gradeLevel--;
            }
            else
              gradeLevel++;
          }
        case 1:
          if (playerGrade > 0)
          {
            FlxG.sound.play(Paths.sound('gradeup'));
            goGood();
          }
        case 3:
          if (playerGrade > 1)
          {
            FlxG.sound.play(Paths.sound('gradeup'));
            goBad();
          }
      }
      if (gradeLevel > 0) gradeLevel--;
      FlxG.sound.play(Paths.sound('phrasegood'));
    }
    else if (prevGradeHealth < 0)
    {
      switch (gradeLevel)
      {
        case 1:
          if (playerGrade == 0)
          {
            FlxG.sound.play(Paths.sound('gradedown'));
            goBad();
          }
        case 3:
          if (playerGrade < 2)
          {
            FlxG.sound.play(Paths.sound('gradedown'));
            goAwful();
          }
        case 5:
          PlayState.instance.health = -999;
      }
      if (gradeLevel < 6) gradeLevel++;
      FlxG.sound.play(Paths.sound('phrasebad'));
    }
    if (!doFlicker && gradeLevel % 2 == 1) startFlicker();
    else if (!doFlicker && gradeLevel == -1) startFlicker();
    else if (doFlicker && gradeLevel % 2 == 0) endFlicker();
    else if (doFlicker && gradeLevel == -2) endFlicker();
    gradeHealth = nextGradeHealth;
    nextGradeHealth = 0;
    freestyleHealth = 0;
    daphraseDuration = 0;
  }

  public function freestyleHandler():Void
  {
    var game = PlayState.instance;
    var songPos = Conductor.instance.songPosition;
    var stepCrochet = Conductor.instance.stepLengthMs;

    var upP = game.controls.NOTE_UP_P;
    var rightP = game.controls.NOTE_RIGHT_P;
    var downP = game.controls.NOTE_DOWN_P;
    var leftP = game.controls.NOTE_LEFT_P;

    var holdIndex = FlxG.keys.anyPressed([Save.instance.modOptions.get("keyboard_indexHold")]);
    var restartIndex = FlxG.keys.anyPressed([Save.instance.modOptions.get("keyboard_indexReset")]);

    var noteDiff:Float = Math.abs(lastStepTime - songPos);
    var noteDiff2:Float = Math.abs(lastStepTime + stepCrochet - songPos);

    // How Late/Early you can be from a step to count as good freestyle? Default: 17.3
    // 150 for practice (every hit is good freestyle)
    // 17.3 for standard play
    // 60% of step length for easy freestyle
    var maxDiff = game.isPracticeMode ? 150 : stepCrochet * 0.3;
    if (verboseMode)
    {
      trace("Diff1: " + noteDiff);
      trace("Diff2: " + noteDiff2);
      trace("STEP FRAME: " + stepCrochet);
      trace("STEP TIME: " + lastStepTime);
      trace("STEP: " + game.conductorInUse.currentStep);
      trace("MAX: " + maxDiff);
    }

    if (noteDiff <= maxDiff || noteDiff2 <= maxDiff)
    {
      if (lastFreestyleHit != -6000 && game.conductorInUse.songPosition - lastFreestyleHit < stepCrochet * 0.9)
      {
        if (verboseMode) trace("TOO MUCH ARROW HITS!!!");
        if (showFreestyleJudgements) game.comboPopUps.displayRating("bad");
        freestyleHealth -= freestyleHealthLoss;
        gradeHealth -= 0.02;
        game.songScore -= 10;
      }
      else
      {
        // The closest step
        var stepHit:Int = game.conductorInUse.currentStep;
        if (noteDiff2 < noteDiff) stepHit++;

        if (stepHit % 2 == 0)
        {
          // on beat
          if (verboseMode) trace("GOOD!");
          freestyleHealth += freestyleHealthOnBeatGain;
          gradeHealth += 0.01;
          if (playerGrade == -1) game.songScore += 200;
          if (showFreestyleJudgements) game.comboPopUps.displayRating("good");
        }
        else
        {
          // off beat
          if (verboseMode) trace("EXCELLENT!");
          freestyleHealth += freestyleHealthOnBeatGain;
          gradeHealth += 0.01;
          if (playerGrade == -1) game.songScore += 200;
          if (showFreestyleJudgements) game.comboPopUps.displayRating("sick");
        }
      }

      lastFreestyleHit = game.conductorInUse.songPosition;
    }
    else
    {
      if (verboseMode) trace("BAD!");
      if (showFreestyleJudgements) game.comboPopUps.displayRating("bad");
      if (playerGrade > -1)
      {
        freestyleHealth -= freestyleHealthLoss;
        gradeHealth -= 0.02;
        game.songScore -= 10;
      }
    }

    var daFreestyleArray:Array<FunkinSound> = freestyleSoundsL;
    var freestyleCurrentArrow:Int = 0;
    var bf = game.currentStage.getBoyfriend();
    if (leftP)
    {
      bf.animation.finish();
      bf.playAnimation("singLEFT", true);
      daFreestyleArray = freestyleSoundsL;
      freestyleCurrentArrow = 0;
    }
    else if (downP)
    {
      bf.animation.finish();
      bf.playAnimation("singDOWN", true);
      daFreestyleArray = freestyleSoundsD;
      freestyleCurrentArrow = 1;
    }
    else if (upP)
    {
      bf.animation.finish();
      bf.playAnimation("singUP", true);
      daFreestyleArray = freestyleSoundsU;
      freestyleCurrentArrow = 2;
    }
    else if (rightP)
    {
      bf.animation.finish();
      bf.playAnimation("singRIGHT", true);
      daFreestyleArray = freestyleSoundsR;
      freestyleCurrentArrow = 3;
    }
    else
    {
      trace("?????????");
    }

    freestyleSound.stop();

    var isSameArrow = freestyleCurrentArrow == freestylePrevArrow;
    if (restartIndex) freestyleSoundIndex = 0;

    if (playerGrade == -1 && holdIndex && isSameArrow)
    {
      if (freestyleSoundIndex == 0) freestyleSoundIndex = daFreestyleArray.length - 1;
      else
        freestyleSoundIndex--;
    }

    if (verboseMode)
    {
      // We do a modulo here in case we have invalid index or sth
      trace(freestyleSoundIndex % daFreestyleArray.length);
      trace(Std.string(freestyleSoundIndex) + " / " + Std.string(daFreestyleArray.length));
    }

    freestyleSound = daFreestyleArray[freestyleSoundIndex % daFreestyleArray.length];
    if (playerGrade == -1 && isSameArrow) freestyleSoundIndex++;

    if (freestyleSoundIndex > daFreestyleArray.length - 1)
    {
      freestyleSoundIndex = 0;
      trace("RESET!!!");
    }

    freestylePrevArrow = freestyleCurrentArrow;

    trace(Std.string(freestyleSoundIndex));
    if (freestyleSound != null) freestyleSound.play(true);
  }

  function goCool():Void
  {
    changedSongGrade = false;
    filters.resize(0);
    changedSongGrade = true;
    gradeTxtCool.color = 0xFFFFFFFF;
    gradeTxtGood.color = 0xFF808080;
    gradeTxtBad.color = 0xFF808080;
    gradeTxtAwful.color = 0xFF808080;
    gradeTxtMarker.y = gradeTxtCool.y;
    if (FlxG.onMobile)
    {
      if (Save.instance.options.controlsScheme == "Arrows")
      {
        PlayState.instance.playerStrumline.notes.visible = false;
        PlayState.instance.playerStrumline.holdNotes.visible = false;
      }
      else
        PlayState.instance.playerStrumline.visible = false;
    }
    else
      PlayState.instance.playerStrumline.visible = false;
    PlayState.instance.opponentStrumline.visible = false;
    PlayState.instance.vocals.volume = 0;
    playerGrade = -1;
  }

  function goGood():Void
  {
    filters.resize(0);
    var checkFileExists:Bool = false;
    gradeTxtCool.color = 0xFF808080;
    gradeTxtGood.color = 0xFFFFFFFF;
    gradeTxtBad.color = 0xFF808080;
    gradeTxtAwful.color = 0xFF808080;
    gradeTxtMarker.y = gradeTxtGood.y;
    if (FlxG.onMobile)
    {
      PlayState.instance.playerStrumline.notes.visible = true;
      PlayState.instance.playerStrumline.holdNotes.visible = true;
    }
    else
      PlayState.instance.playerStrumline.visible = true;
    PlayState.instance.opponentStrumline.visible = true;
    if (FlxG.onMobile)
    {
      PlayState.instance.opponentStrumline.notes.visible = false;
      PlayState.instance.opponentStrumline.holdNotes.visible = false;
    }
    PlayState.instance.vocals.volume = 1;
    playerGrade = 0;
  }

  function goBad():Void
  {
    filters.resize(0);
    filters.push(filterMap.get("BlurBad").filter);
    filters.push(filterMap.get("Bad").filter);
    changedSongGrade = true;
    gradeTxtCool.color = 0xFF808080;
    gradeTxtGood.color = 0xFF808080;
    gradeTxtBad.color = 0xFFFFFFFF;
    gradeTxtAwful.color = 0xFF808080;
    gradeTxtMarker.y = gradeTxtBad.y;
    playerGrade = 1;
  }

  function goAwful():Void
  {
    filters.resize(0);
    filters.push(filterMap.get("BlurAwful").filter);
    filters.push(filterMap.get("Awful").filter);
    changedSongGrade = true;
    gradeTxtCool.color = 0xFF808080;
    gradeTxtGood.color = 0xFF808080;
    gradeTxtBad.color = 0xFF808080;
    gradeTxtAwful.color = 0xFFFFFFFF;
    gradeTxtMarker.y = gradeTxtAwful.y;
    playerGrade = 2;
  }

  override function onSongEnd(event:ScriptEvent)
  {
    super.onSongEnd(event);
    if (!Save.instance.modOptions.get("parappaToggle")) return;
    songEnded = true;
    if (oldTiming) doParappaGrading();
    if (playerGrade > 0 && requireGood)
    {
      event.cancel();
      PlayState.instance.isPracticeMode = false;
      PlayState.instance.health = -999;
      return;
    }
  }

  override function onNoteGhostMiss(event:GhostMissNoteScriptEvent)
  {
    if (enableCool)
    {
      freestyleHandler();
      event.scoreChange = 0;
      event.cancelEvent();
      event.stopPropagation();
    }
    super.onNoteGhostMiss(event);
  }

  override function onNoteMiss(event:NoteScriptEvent)
  {
    if (!Save.instance.modOptions.get("parappaToggle")) return;
    if (playerGrade == -1)
    {
      // Eric, why is "onNoteHoldDrop" not cancelable???
      if (event.note.isHoldNote) event.note.holdNoteSprite.kill();

      // In cool mode player doesn't have a chance to play normal notes, so we don't count those
      Highscore.tallies.totalNotes--;
      event.note.kill();
      event.cancel();
      event.stopPropagation();
    }
    super.onNoteMiss(event);
    gradeHealth -= 0.1;
    PlayState.instance.health += 2;
  }

  override function onNoteHit(event:HitNoteScriptEvent)
  {
    if (!Save.instance.modOptions.get("parappaToggle")) return;
    var game = PlayState.instance;
    if (game == null || !game.active) return;

    if (playerGrade == -1)
    {
      if (event.note.noteData.getMustHitNote()) freestyleHandler();
      event.score = 0;
      event.cancel();
      event.stopPropagation();
      return;
    }
    super.onNoteHit(event);
    if (event.note.noteData.getMustHitNote()) gradeHealth += 0.04;
  }

  override function onSongEvent(event:SongEventScriptEvent)
  {
    if (!Save.instance.modOptions.get("parappaToggle")) return;
    if (playerGrade == -1 && event.eventData.eventKind == "FocusCamera")
    {
      event.eventData.value =
        {
          char: 0
        };
    }
    trace(event.eventData.value);
    super.onSongEvent(event);
  }

  override function onStepHit(event:SongTimeScriptEvent)
  {
    if (!Save.instance.modOptions.get("parappaToggle")) return;
    lastStepTime = Conductor.instance.songPosition;
    super.onStepHit(event);
  }

  override function onSongRetry(event:SongRetryEvent)
  {
    if (!Save.instance.modOptions.get("parappaToggle")) return;
    goGood();
    super.onSongRetry(event);
  }
}

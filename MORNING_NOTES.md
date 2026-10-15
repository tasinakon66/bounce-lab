# Morning notes - what I did overnight

Good morning Tasin. Everything below is in your bounce-lab folder. Nothing is committed yet: open GitHub Desktop, look through the changes, and commit if you like them.

## 1. What I found (market + psychology)

**Who's already doing this:**
- **Satisfying-ball channels** (satisfying.ba11s, Jack's Physics, CodeCraftedPhysics) get millions of views per Short. One melody-bounce video hit 38M+ views in five months. The demand is real.
- **Tools that already exist:** BallSimule (web, ~US$25/mo), BallEngine.app (web, US$19-199/mo, 10 modes, auto-posting), and Ball Chaos (iOS, has a community and remixes).
- **What they all miss:**
  1. **Personal content.** Everyone makes generic videos. Nobody lets you put *your mum, your friends, your cat* into a merge chain or a battle. Personal videos get shared outside the "satisfying" niche: people send them to the group chat, tag family, and so on. That's our wedge.
  2. **Free and phone-first.** The competitors are paid web tools.
  3. **Engagement built in.** Battles and races ("pick a racer", "who wins?") make people comment, and comments push the algorithm.

**Why people can't stop watching (and how the app uses it):**
- **Open loop:** a question at the top ("Can it reach the final fruit?") means the brain wants the answer. → Every template has a **hook** line.
- **Visible progress:** a goal plus a progress bar keeps people watching to the end. → Merge level ladder, fill %, rings left, size %, health bars.
- **Escalation:** it gets bigger, faster and higher-pitched as it goes. → Rising notes, speed ramps, final showdown.
- **Near-misses and setbacks:** these build tension before the payoff. → Spikes cut the ball in half; crits in battles.
- **Big payoff:** flash, shake, sparks, a pop-in, a chord. → Same win moment everywhere, and the merge ending shows the final picture huge.
- **Loop and CTA:** the video ends with "Follow for part 2!" and loops cleanly. → **Ending message** field, auto-restart.
- **Watermark:** "made with BounceLab" on every video is free advertising, the same way CapCut grew. (You can switch it off.)

## 2. What I built

- **A real app structure:** a home screen with a **template gallery** (live thumbnails rendered from each template), then an **editor**, then **preview** and **record**. The code is split cleanly: `main.gd` is the app, `templates/` holds one file per Reel, and `base_template.gd` holds the shared look. Adding a new template is one file. See README.md.
- **7 templates**, all in the same neon/space style:
  1. **Merge Flask**: the Reel you showed me, now with a final-form pop-in.
  2. **Friend Battle** *(new)*: photos crash, with health bars, CRITs and a final showdown.
  3. **Marble Race** *(new)*: racers drop through pegs and spinners to a chequered finish, with a podium.
  4. **Grow & Spikes**: grows every bounce, and spikes cut it in half.
  5. **Fill the Circle**: every bounce = a new ball, with a % meter.
  6. **Escape the Rings**: spinning rings with gaps, and each escape shatters one.
  7. **Melody Bounce**: guess the song, using public-domain melodies only.
- **The editor** lets you set: the hook text, theme text, ending message, names (battle/race), picture pack or **a photo per level**, sound, glow colour (5), background (space / black / grid / sunset), watermark on/off, and per-template physics sliders. Settings are remembered between launches.
- **RECORD VIDEO actually works.** It opens a second window that plays the Reel once at **1080x1920, 60fps, with sound**, closes itself, and saves to **Videos\BounceLab\**. I tested this end to end on my side (real video file, audio track present).
- **README.md** with screenshots (in `docs/`), ready for GitHub and your portfolio.

Every template was run and screenshotted on my side, and the difficulty was tuned so each Reel ends in about 30-70 seconds.

## 3. What to check this morning (10 minutes)

1. Open Godot, then BounceLab. Wait for it to import the new files, then press **F5**.
2. You should see the **template gallery**. Try **Merge Flask**, then **PREVIEW**.
3. Back in the editor, set **Pictures: MY PHOTOS** and pick a few photos, then preview again.
4. Press **RECORD VIDEO**. A window plays the Reel and closes by itself. Then check **Videos\BounceLab**.
5. Try **Friend Battle** with your friends' names and photos.

## 4. Things that might be different on your PC

- **Recording size:** your monitor is 1080 pixels tall, and the recorder asks for a 1920-tall window. If Windows shrinks it, the video comes out smaller than 1080x1920. Tell me the size you get and I'll fix it (there's a second method I can switch to).
- **Unused old files:** `arena.gd` and `game_settings.gd` aren't used any more. They're safe to delete.
- **Godot import:** the first open after this update may show a few seconds of "importing". That's normal.

## 5. Suggested next steps

1. **Test the market for free:** start a TikTok/IG account and post one Friend Battle or Merge Reel a day for two weeks. Track the views.
2. **Phone version:** export to Android and handle recording on the phone (that needs a different recorder than the PC one).
3. **More templates and themes:** add the trending ones you find, which is now one file each.
4. **AI themes later:** type "sports balls" and the app generates all 10 level pictures.

## Commit message suggestion

`App rebuild: template gallery, editor, 7 templates, one-click 1080x1920 recording`

# Website Asset Recipes

This directory documents how we create source media for the public website.

## Recording Loops

1. Open the app in the Xcode Simulator.
2. Use the simulator's **Record Screen** function to capture the animation.
3. Open the recording in QuickTime Player.
4. Trim the clip to a seamless loop (Edit > Trim), and save it as `input.mov`.
5. Take a screenshot to use as the still frame fallback image.

## Encoding

Encode every loop being published with the same command, changing only the
output name.

```bash
ffmpeg -i input.mov \
  -c:v libx264 \
  -crf 23 \
  -preset slow \
  -pix_fmt yuv420p \
  -an \
  -vf "scale=-2:1240:flags=lanczos,fps=30" \
  -movflags +faststart \
  OUTPUT.mp4
```

Flag notes:

- `-i input.mov`: reads the trimmed QuickTime export.
- `-c:v libx264`: encodes the video as H.264 for broad browser compatibility in
  an MP4 container.
- `-crf 23`: sets constant quality. Lower values improve quality and increase
  file size; higher values reduce file size.
- `-preset slow`: spends more encoding time to improve compression efficiency.
  This is a good fit because the loop is generated manually and does not need to
  encode in real time.
- `-pix_fmt yuv420p`: writes a widely compatible pixel format for browser and
  device playback.
- `-an`: removes audio. The loop is silent, and removing audio avoids extra file
  size and autoplay issues on the web.
- `-vf "scale=-2:1240:flags=lanczos,fps=30"`: chains three things.
  - `scale=-2:1240`: scales the height to 1240 px and automatically chooses an
    even width that preserves the aspect ratio. This keeps the source roughly 2x
    the CSS-rendered feature screenshot size on the website.
  - `flags=lanczos`: uses Lanczos resampling for a sharper downscale, reducing
    shimmer on fine UI lines (piano keys, small text) during static holds.
  - `fps=30`: forces a constant 30 fps. Phone and simulator screen recordings
    are variable frame rate (a frame is only emitted when the screen changes),
    which browsers play back unevenly in a loop. Resampling to a constant rate
    removes that stutter. Confirm with `ffprobe` that `r_frame_rate` reads
    `30/1`.
- `-movflags +faststart`: moves MP4 metadata to the beginning of the file so the
  browser can begin playback before downloading the whole video.
- `OUTPUT.mp4`: the per-clip output name (`real_time.mp4`, `explore_modes.mp4`).

## Image Processing

Convert any screenshot images from _png_ to _webp_ using the `shotproc` utility
from [toolbox-envy][] (it's a convenience wrapper around the ImageMagick CLI).

```
$ shotproc ~/Desktop/real_time.png docs/site/public/images/real_time.webp
```

The diagonal merge hero image is created from combining a light mode and a dark
mode screenshot together using the `diagmerge` utility from [toolbox-envy][].

```
$ diagmerge ~/Desktop/light_mode.png ~/Desktop/dark_mode.png docs/site/public/images/theme_modes.webp
```

[toolbox-envy]: https://github.com/EarthmanMuons/toolbox-envy

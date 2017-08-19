# MusicBot

A [Discord] bot that plays audio from youtube over the voice channel.

[Discord]: https://discordapp.com/

## Commands

> !play `<query>`

Searchs youtube with query provided and adds first video to play queue.

> !pause

Pause the current song.

> !unpause

Unpause the current song.

> !playlist

Outputs playlist to channel.

## Dependencies

For this bot to work right, you must have [dca-rs] & [youtube-dl] in the path.
[dca-rs binaries] and [youtube-dl binaries] are available for Windows, Mac,
and Linux.

[dca-rs]: https://github.com/nstafie/dca-rs
[youtube-dl]: https://rg3.github.io/youtube-dl/
[dca-rs precompiled binaries]: https://github.com/nstafie/dca-rs/releases
[youtube-dl binaries]: https://rg3.github.io/youtube-dl/download.html

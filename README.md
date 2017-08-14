# MusicBot

A [Discord] bot that plays audio files over the voice channel.

[Discord]: https://discordapp.com/

## Commands

> !play `<filename>`

Start this song playing. If there is another song already playing, it will be replaced, otherwise MusicBot will start playing.

> !pause

Pause the current song.

> !unpause

Unpause the current song.

> !stop

Clears the current song and stops playing it.

## Dependencies

For this bot to work right, you must have [dca-rs] in the path.
[Precompiled binaries] are available for Windows, Mac, and Linux.

[dca-rs]: https://github.com/nstafie/dca-rs
[Precompiled binaries]: https://github.com/nstafie/dca-rs/releases

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `music_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:music_ex, "~> 0.1.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/music_ex](https://hexdocs.pm/music_ex).


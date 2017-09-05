defmodule MusicExDiscord.Discord.Voice.Encoder do
  def encode(file) do
    c = "dca-rs -i #{file} --raw -b 64"
    %Porcelain.Result{out: opus_data, status: 0} = Porcelain.shell(c)

    split_packets([], opus_data)
  end

  def split_packets(acc, <<>>) do
    acc
  end

  def split_packets(acc, opus_data) when is_binary(opus_data) do
    <<opus_len::little-signed-16, opus_packet::binary-size(opus_len), opus_data::binary>> = opus_data
    split_packets(acc ++ [ opus_packet ], opus_data)
  end

  def rtp_header(seq, ssrc) do
    <<0x80::size(8), 0x78::size(8), seq::size(16), (seq*960)::size(32), ssrc::size(32)>>
  end

  def encrypt_packet(packet, header, secret_key) do
    nonce = (header <> <<0::size(96)>>)
    Kcl.secretbox(packet, nonce, secret_key)
  end
end

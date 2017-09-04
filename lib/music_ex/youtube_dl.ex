defmodule MusicEx.YoutubeDL do
  def binary_to_file(request) do
    {:ok, tmp_path} = Temp.path("music-ex")
    Temp.track!(tmp_path)
    binary_request(request, tmp_path)

    tmp_path
  end

  def metadata(request) do
    metadata_request(request)
    |> Poison.decode!()
    |> format_json()
  end

  defp url(request) do
    query = URI.encode_www_form(request)
    "https://www.youtube.com/results?search_query=#{query}&page=1"
  end

  defp metadata_request(request) do
    c = "youtube-dl --print-json -q -s -i -f bestaudio --playlist-items 1 '#{url(request)}'"
    retry(c)
  end

  defp binary_request(request, file) do
    c = "youtube-dl -q -o - -i -f bestaudio --playlist-items 1 '#{url(request)}' > #{file}"
    retry(c)
  end

  defp retry(command, runs \\ 0) do
    IO.puts("Run ##{inspect(runs)} of #{inspect(command)}")
    case Porcelain.shell(command) do
      %Porcelain.Result{status: 1} ->
        case runs do
          3 -> raise "Failed to run #{inspect(command)} three times"
          _ -> retry(command, runs + 1)
        end
      %Porcelain.Result{out: output, status: 0} ->
        output
    end
  end

  defp format_json(json) do
    Map.take(json, [
      "webpage_url",
      "id",
      "fulltitle",
      "duration"
    ])
  end
end

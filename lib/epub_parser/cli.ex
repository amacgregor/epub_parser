defmodule EpubParser.CLI do
  def main(args) do
    {opts, _, _} =
      OptionParser.parse(
        args,
        switches: [source: :string, destination: :string, dry_run: :boolean],
        aliases: [s: :source, d: :destination]
      )

    print_title("Selected Options")
    IO.inspect(opts)

    book_list =
      generate_list(opts[:source])

    # DESTINATION_PATH/AUTHOR(S)/TITLE-VERSION-DATE_CREATED.epub
    # TODO: Implement Dry run mode
    # TODO: Make this a progress bar
    for {:ok, path, metadata} <- book_list do
      # Extract Data
      metadata_title =
        metadata.title
        |> String.replace(~r/\ \(for\ \w* \w*\)/, "")
        |> String.replace(~r/\ \(for\ \w* \w* \w*\)/, "")

      # Generate Date tag
      # TODO: This should be the publication date
      {:ok, original_file_data} = File.stat(path)
      {:ok, erl_datetime} = NaiveDateTime.from_erl(original_file_data.ctime)

      date_tag = erl_datetime
        |> NaiveDateTime.to_date
        |> Date.to_string

      # Generate Destination Path
      version = Regex.split(~r{_},Path.basename(path, ".epub"))
      new_title = sanitize_title("#{metadata_title} #{Enum.at(version,1)} [#{date_tag}]")
      new_filename = sanitize_filename(sanitize_path("#{metadata_title}") <> "_#{Enum.at(version,1)}_#{date_tag}") <> ".epub"
      new_path = sanitize_path("#{opts[:destination]}/#{metadata.creator}/")

      # Create directory
      File.mkdir_p!(Path.dirname(new_path))

      # Move the file
      File.rename(path, new_path <> new_filename)

      # Update Ebook Metadata (title and version)
      System.cmd("/Applications/calibre.app/Contents/MacOS/ebook-meta", ["#{new_path}#{new_filename}", "-t", "#{new_title}"])

      # TODO: Make this only show on verbose mode
      IO.inspect(metadata.title, label: "Old Title")
      IO.inspect(path, label: "Old Path")

      IO.inspect(new_title, label: "New Title")
      IO.inspect(new_path <> new_filename, label: "New Path")
      IO.puts("\r\n")
    end

    for {:error, error} <- book_list do
      IO.inspect(error)
    end
  end

  defp sanitize_path(string) do
    string = string
      |> String.replace(~r/ /, "-")
      |> String.replace(~r/--/, "-")
      |> String.replace(~r/\./, "")
      |> String.replace(~r/\:/, "")
      |> String.replace(~r/\'/, "")
      |> String.replace(~r/\’/, "")
      |> String.replace(~r/\,/, "")
      |> String.replace(~r/\®/, "")
      |> String.replace(~r/\≥/, "")
      |> String.replace(~r/__/, "-")
      |> String.replace(~r/\&/, "and")
  end

  defp sanitize_title(string) do
    string = string
      |> String.replace(~r/  /, " ")
  end

  defp sanitize_filename(string) do
    string = string
      |> String.replace(~r/--/, "-")
      |> String.replace(~r/__/, "_")
      |> String.replace(~r/\//, "-")
  end

  defp report_errors() do

  end

  defp generate_list(source) do
    format = [
      frames: :braille,   # Or an atom, see below
      text: "Loading…",
      done: "Loaded.",
      spinner_color: IO.ANSI.magenta,
      interval: 100,  # milliseconds between frames
    ]

    print_title("Building the file list")
    ProgressBar.render_spinner format, fn ->
      Path.wildcard(source <> "/*.epub")
      |>Enum.map(&extract_metadata/1)
    end
  end

  defp extract_metadata(path) do
    try do
      {:ok, path, BUPE.parse(path)}
    rescue
      e in RuntimeError -> {:error, e}
      e in ErlangError -> {:error, e}
    end
  end

  def print_title(text) do
    IO.inspect(text, label: "Section")
  end
end

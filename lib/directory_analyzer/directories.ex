defmodule DirectoryAnalyzer.Directories do
  @moduledoc """
  The Directories context.
  """

  import Ecto.Query, warn: false
  alias DirectoryAnalyzer.Repo

  alias DirectoryAnalyzer.Directories.Directory

  @doc """
  Returns the list of directories.

  ## Examples

      iex> list_directories()
      [%Directory{}, ...]

  """
  def list_directories do
    Repo.all(Directory)
  end

  @doc """
  Gets a single directory.

  Raises `Ecto.NoResultsError` if the Directory does not exist.

  ## Examples

      iex> get_directory!(123)
      %Directory{}

      iex> get_directory!(456)
      ** (Ecto.NoResultsError)

  """
  def get_directory!(id), do: Repo.get!(Directory, id)

  @doc """
  Creates a directory.

  ## Examples

      iex> create_directory(%{field: value})
      {:ok, %Directory{}}

      iex> create_directory(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """

  def create_directory(attrs \\ %{}) do
    %Directory{}
    |> Directory.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a directory.

  ## Examples

  iex> delete_directory(directory)
  {:ok, %Directory{}}

  iex> delete_directory(directory)
  {:error, %Ecto.Changeset{}}

  """
  def delete_directory(%Directory{} = directory) do
    Repo.delete(directory)
  end

  @doc """
  Evaluates directory for word count stats
  ## Examples

      iex> evaluate_directory(name)
      {:ok, %{name: name, word_count: word_count, file_count: file_count, name: name}}

      iex> evaluate_directory(name)
      {:error, message}

  """
  def evaluate_directory(name) do
    case list_files(name) do
      {:ok, files} ->
        process_directory(name, files)

      {:error, message} ->
        {:error, message}
    end
  end

  defp list_files(name) do
    # -- get absolute path name for directory
    # -- find all txt files within directory <--- safe to say that it will ignore any non text file.
    files =
      Path.absname("documents/#{name}")
      |> Kernel.<>("/*.txt")
      |> Path.wildcard()

    case length(files) do
      0 ->
        {:error, "There are no .txt files in this directory"}

      _ ->
        {:ok, files}
    end
  end

  defp process_directory(name, files) do
    result =
      files
      |> Enum.map(fn file ->
        process_file(file)
      end)
      |> List.flatten()
      |> Enum.reduce(%{word_count: 0, words: %{}}, fn word,
                                                      %{word_count: word_count, words: words} =
                                                        acc ->
        words = Map.update(words, word, 1, fn existing_value -> existing_value + 1 end)

        %{acc | word_count: word_count + 1, words: words}
      end)
      |> Map.merge(%{file_count: length(files), name: name})

    # sorting by count is working, yet both count and word are descending so the ordering on the words is reverse alphabetized.
    top_ten_words =
      Enum.sort_by(result.words, fn {word, count} -> {count, word} end, &>=/2)
      |> Enum.slice(0..9)

    {:ok, %{result | words: top_ten_words}}
  end

  defp process_file(file) do
    # TODO fix last map to handle ignore only all caps I's
    file
    |> File.stream!()
    |> Enum.map(&String.replace(&1, ~r/([[:punct:]]|[[:digit:]])/, ""))
    |> Enum.map(&Regex.replace(~r/\b(?:(?!I)\w)+\b/, &1, fn a, _ -> String.downcase(a) end))
    |> Enum.filter(fn s -> s !== "\n" end)
    |> Enum.map(&String.replace(&1, ~r/(\n+)/, ""))
    |> Enum.map(&String.split/1)
  end
end

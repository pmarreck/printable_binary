defmodule PrintableBinaryTest do
  use ExUnit.Case, async: true
  import PrintableBinary
  doctest PrintableBinary

	@canonical_map_path Path.expand("../../character_map.txt", __DIR__)
	@external_resource @canonical_map_path
	@canonical_map_source File.read!(@canonical_map_path)

	test "test runtime uses UTF-8 native file names" do
		assert :file.native_name_encoding() == :utf8
	end

  test "~PB decodes passthrough ASCII to itself" do
    assert ~PB"AB" == "AB"
  end

  test "~PB decodes control-char glyphs (byte 0 -> ·)" do
    assert PrintableBinary.decode("·") == <<0>>
  end

  test "whitespace inside the sigil is ignored (heredoc/wrapping-safe)" do
    assert ~PB"A B" == "AB"
    assert ~PB"""
           A
           B
           """ == "AB"
  end

  test "decode/1 round-trips all 256 single-byte glyphs" do
    # Build the inverse (byte -> glyph) from the same source, then decode each glyph.
    byte_to_glyph =
      @canonical_map_source
      |> String.split("\n")
      |> Enum.map(&String.trim_trailing(&1, "\r"))
      |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "##")))
      |> Enum.map(&(&1 |> String.split() |> hd()))

    assert length(byte_to_glyph) == 256

    for {glyph, byte} <- Enum.with_index(byte_to_glyph) do
      assert PrintableBinary.decode(glyph) == <<byte>>, "byte #{byte} glyph #{inspect(glyph)}"
      assert PrintableBinary.decode_strict!(glyph) == <<byte>>, "strict byte #{byte} glyph #{inspect(glyph)}"
    end
  end

  test "unrecognized glyph raises" do
    assert_raise ArgumentError, fn -> PrintableBinary.decode_strict!("🚫") end
  end

  test "recovery resumes at exact glyph after a malformed UTF-8 prefix" do
    assert report(<<0xE0, 0xC2, 0xB6>>) ==
             {<<0xE0, 10>>, %{invalid_events: 1, invalid_bytes: 1},
              [event(0, 0, <<0xE0>>)]}

    assert PrintableBinary.decode(<<0xE0, 0xC2, 0xB6>>) == <<0xE0, 10>>
  end

  test "unknown Unicode and NUL are preserved with byte-based spans" do
    input = "¶🚫A" <> <<0, 0xFF, 0x80>> <> "·"

    assert report(input) ==
             {<<10>> <> "🚫A" <> <<0, 0xFF, 0x80, 0>>,
              %{invalid_events: 2, invalid_bytes: 7},
              [event(2, 1, "🚫"), event(7, 6, <<0, 0xFF, 0x80>>)]}
  end

  test "canonical complete alphabet and empty input report zero errors" do
    glyphs = canonical_glyphs()
    raw = :erlang.list_to_binary(Enum.to_list(0..255))

    assert report(IO.iodata_to_binary(glyphs)) ==
             {raw, %{invalid_events: 0, invalid_bytes: 0}, []}

    assert report(<<>>) == {<<>>, %{invalid_events: 0, invalid_bytes: 0}, []}
  end

  test "maximal invalid regions end at accepted glyphs, not UTF-8 boundaries" do
    input = <<0xFF, 0x80>> <> "🚫A" <> <<0, 0xFE>> <> "¶" <> <<0xFF>>

    assert report(input) ==
             {<<0xFF, 0x80>> <> "🚫A" <> <<0, 0xFE, 10, 0xFF>>,
              %{invalid_events: 3, invalid_bytes: 9},
              [event(0, 0, <<0xFF, 0x80>> <> "🚫"),
               event(7, 7, <<0, 0xFE>>), event(11, 10, <<0xFF>>)]}
  end

  test "raw whitespace is invalid unless transport or literal-space policy accepts it" do
    input = <<0xFF, 32, 0x80, 9, 0, 13, 0xFE, 10, 0xFD>>
    assert PrintableBinary.decode(input) == input
    assert report(input) == {input, %{invalid_events: 1, invalid_bytes: 9}, [event(0, 0, input)]}

    assert report(input, strip_whitespace: true) ==
             {<<0xFF, 0x80, 0, 0xFE, 0xFD>>, %{invalid_events: 5, invalid_bytes: 5},
              [event(0, 0, <<0xFF>>), event(2, 1, <<0x80>>), event(4, 2, <<0>>),
               event(6, 3, <<0xFE>>), event(8, 4, <<0xFD>>)]}

    assert report(" A␣", spaces: true) == {" A ", %{invalid_events: 0, invalid_bytes: 0}, []}
    assert report(" \tA", spaces: true, strip_whitespace: true) ==
             {" A", %{invalid_events: 0, invalid_bytes: 0}, []}
  end

  test "ignored whitespace never splices malformed glyph fragments" do
    assert report(<<0xC2, 32, 0xB6>>, strip_whitespace: true) ==
             {<<0xC2, 0xB6>>, %{invalid_events: 2, invalid_bytes: 2},
              [event(0, 0, <<0xC2>>), event(2, 1, <<0xB6>>)]}
  end

  test "report callbacks propagate failure immediately without accumulating events" do
    sink = fn item ->
      send(self(), {:decode_event, item})
      {:error, :closed}
    end

    assert PrintableBinary.decode_report(<<0xFF, ?A, 0xFE>>, on_error: sink) == {:error, :closed}
    assert received_events() == [event(0, 0, <<0xFF>>)]

    assert_raise RuntimeError, "sink failed", fn ->
      PrintableBinary.decode_report(<<0xFF>>, on_error: fn _ -> raise "sink failed" end)
    end
  end

  test "strict validation stays strict while recovery accepts the same bytes" do
    for bytes <- ["🚫", <<0xE0, 0xC2, 0xB6>>, <<0>>, " ", "\n"] do
      assert_raise ArgumentError, fn -> PrintableBinary.decode_strict!(bytes) end
      assert is_binary(PrintableBinary.decode(bytes))
    end

    assert PrintableBinary.decode_strict!(" A\nB\t", strip_whitespace: true) == "AB"
    assert PrintableBinary.decode_strict!(" A␣", spaces: true) == " A "
  end

  test "all single wire bytes agree with the independent canonical map" do
    single_byte_glyphs =
      canonical_glyphs()
      |> Enum.with_index()
      |> Enum.filter(fn {glyph, _} -> byte_size(glyph) == 1 end)
      |> Map.new()

    for byte <- 0..255 do
      wire = <<byte>>

      expected =
        case Map.fetch(single_byte_glyphs, wire) do
          {:ok, decoded} -> {<<decoded>>, %{invalid_events: 0, invalid_bytes: 0}, []}
          :error -> {wire, %{invalid_events: 1, invalid_bytes: 1}, [event(0, 0, wire)]}
        end

      assert report(wire) == expected, "wire byte #{byte}"
    end
  end

  test "seeded mutations retain exact inserted bytes, event positions, and stream base" do
    glyphs = canonical_glyphs() |> List.to_tuple()
    initial = :rand.seed_s(:exsss, {73, 991, 2026})

    Enum.reduce(1..128, initial, fn trial, state ->
      {first, state} = :rand.uniform_s(256, state)
      {last, state} = :rand.uniform_s(256, state)
      {size, state} = :rand.uniform_s(19, state)
      prefix = elem(glyphs, first - 1)
      suffix = elem(glyphs, last - 1)
      invalid = :binary.copy(<<0xFF, 0>>, size)
      input = prefix <> invalid <> suffix

      assert report(input, input_base: trial) ==
               {<<first - 1>> <> invalid <> <<last - 1>>,
                %{invalid_events: 1, invalid_bytes: byte_size(invalid)},
                [event(trial + byte_size(prefix), 1, invalid)]}

      state
    end)
  end

  test "long invalid span is one full borrowed-wire event" do
    invalid = :binary.copy(<<0xFF>>, 65_539)

    assert report(invalid) ==
             {invalid, %{invalid_events: 1, invalid_bytes: byte_size(invalid)},
              [event(0, 0, invalid)]}
  end

  test "event counts remain exact above the CLI saturation boundary" do
    input = :binary.copy(<<0xFF, ?A>>, 300)
    events = for index <- 0..299, do: event(index * 2, index * 2, <<0xFF>>)
    assert report(input) == {input, %{invalid_events: 300, invalid_bytes: 300}, events}
  end

  test "malformed UTF-8 boundaries preserve every byte and resume at the next glyph" do
    for invalid <- [<<0x80>>, <<0xC0, 0x80>>, <<0xC1, 0xBF>>, <<0xDF>>,
                    <<0xE0, 0x80, 0x80>>, <<0xED, 0xA0, 0x80>>, <<0xEF, 0xBF>>,
                    <<0xF0, 0x80, 0x80, 0x80>>, <<0xF4, 0x90, 0x80, 0x80>>,
                    <<0xF5, 0x80, 0x80, 0x80>>, <<0xF0, 0x9F, 0x9A>>, <<0xFE, 0xFF>>] do
      assert report("·" <> invalid <> "¶") ==
               {<<0>> <> invalid <> <<10>>,
                %{invalid_events: 1, invalid_bytes: byte_size(invalid)},
                [event(2, 1, invalid)]}
    end
  end

  defp canonical_glyphs do
    @canonical_map_source
    |> String.split("\n")
    |> Enum.map(&String.trim_trailing(&1, "\r"))
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "##")))
    |> Enum.map(&(&1 |> String.split() |> hd()))
  end

  defp report(input, options \\ []) do
    on_error = fn item ->
      send(self(), {:decode_event, item})
      :ok
    end

    assert {:ok, bytes, summary} = PrintableBinary.decode_report(input, [on_error: on_error] ++ options)
    {bytes, summary, received_events()}
  end

  defp event(input_offset, output_offset, bytes) do
    %{input_offset: input_offset, output_offset: output_offset,
      input_length: byte_size(bytes), output_length: byte_size(bytes), bytes: bytes}
  end

  defp received_events(events \\ []) do
    receive do
      {:decode_event, item} -> received_events([item | events])
    after
      0 -> Enum.reverse(events)
    end
  end
end

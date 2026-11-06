defmodule PrintableBinary do
  @moduledoc """
  Bytewise printable-binary decoding with byte-preserving malformed-wire recovery.
  `decode/1` returns bytes, `decode_report/2` streams invalid-span diagnostics, and
  `decode_strict!/2` validates without accepting unknown wire bytes.

  The strict compile-time `~PB` sigil embeds decoded bytes directly in the BEAM.
  Unlike the raw decoder, the sigil explicitly ignores wrapping whitespace.

      import PrintableBinary
      @magic ~PB"..."   # decoded to raw bytes at compile time
  """

  @map_path Path.expand("../../character_map.txt", __DIR__)
  @external_resource @map_path

  # byte<->glyph map parsed from the single-source character_map.txt at compile time
  # (same parse rules as every other implementation: `##` = comment, first
  # whitespace-delimited token per line is the glyph, in byte order).
  @glyph_to_byte @map_path
                 |> File.read!()
                 |> String.split("\n")
                 |> Enum.map(&String.trim_trailing(&1, "\r"))
                 |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "##")))
                 |> Enum.map(&(&1 |> String.split() |> hd()))
                 |> Enum.with_index()
                 |> Map.new(fn {glyph, byte} -> {glyph, byte} end)

  @doc """
  Decode exact active-map glyph bytes to a raw binary. Every unknown wire byte
  is copied unchanged, including malformed UTF-8, NUL, and raw whitespace.
  Recovery advances one byte at a time, so a following valid glyph is not lost.
  Use `decode_report/2` for diagnostics or explicit whitespace options, and
  `decode_strict!/2` when accepting only recognized input is required.
  """
  @spec decode(binary()) :: binary()
  def decode(input) when is_binary(input) do
    {:ok, bytes, _summary} = decode_report(input)
    bytes
  end

  @type error_event :: %{
          input_offset: non_neg_integer(),
          output_offset: non_neg_integer(),
          input_length: pos_integer(),
          output_length: pos_integer(),
          bytes: binary()
        }
  @type summary :: %{invalid_events: non_neg_integer(), invalid_bytes: non_neg_integer()}
  @type decode_option ::
          {:spaces, boolean()}
          | {:strip_whitespace, boolean()}
          | {:input_base, non_neg_integer()}
          | {:on_error, (error_event() -> :ok | {:error, term()})}

  @doc """
  Recover bytes and return `{:ok, bytes, summary}`, or `{:error, reason}` if the
  diagnostic callback fails. Unknown contiguous wire bytes form one event;
  accepted glyphs and ignored whitespace terminate that event.

  Options are `spaces` (accept literal ASCII spaces) and `strip_whitespace`
  (ignore ASCII space, tab, CR, LF), both defaulting to `false`, `input_base: 0`
  (add a byte offset to original-wire event positions), and `on_error: callback`.
  Literal-space acceptance takes precedence over stripping. Ignoring whitespace
  does not join glyph fragments on either side of it.

  The callback receives each event immediately when its span ends and must
  return `:ok` or `{:error, reason}`. Exceptions and throws propagate. Event
  `bytes` are binary slices of the original input, not repaired text; the VM
  controls whether a slice shares storage. Offsets and lengths count bytes, not
  Unicode characters. No event list is accumulated by the decoder. Recovery is
  intentionally broader than strict canonical validation.
  """
  @spec decode_report(binary(), [decode_option()]) ::
          {:ok, binary(), summary()} | {:error, term()}
  def decode_report(input, options \\ []) when is_binary(input) do
    options = Keyword.validate!(options,
      spaces: false, strip_whitespace: false, input_base: 0, on_error: fn _ -> :ok end)
    config = Map.new(options)

    unless is_boolean(config.spaces) and is_boolean(config.strip_whitespace) and
             is_integer(config.input_base) and config.input_base >= 0 and
             is_function(config.on_error, 1) do
      raise ArgumentError, "invalid printable-binary decoder options"
    end

    walk(input, input, 0, 0, [], nil, %{invalid_events: 0, invalid_bytes: 0}, config)
  end

  @doc """
  Strictly decode recognized glyphs, raising `ArgumentError` at the first
  invalid span. The same explicit `spaces`, `strip_whitespace`, and `input_base`
  options as `decode_report/2` are supported; no callback option is accepted.
  Raw whitespace is invalid by default. The `~PB` sigil explicitly selects
  `strip_whitespace: true` to preserve its wrapping/heredoc convenience.
  """
  @spec decode_strict!(binary(), keyword()) :: binary()
  def decode_strict!(input, options \\ []) when is_binary(input) do
    options = Keyword.validate!(options, [:spaces, :strip_whitespace, :input_base])
    on_error = fn event ->
      raise ArgumentError,
        "invalid printable-binary wire bytes at offset #{event.input_offset}: #{inspect(event.bytes)}"
    end
    {:ok, bytes, _summary} = decode_report(input, [{:on_error, on_error} | options])
    bytes
  end

  defp walk(<<>>, wire, position, output_position, output, pending, summary, config) do
    case close_error(wire, position, output_position, output, pending, summary, config) do
      {:ok, output, summary} -> {:ok, IO.iodata_to_binary(Enum.reverse(output)), summary}
      {:error, _reason} = error -> error
    end
  end

  defp walk(input, wire, position, output_position, output, pending, summary, config) do
    case token(input, config) do
      :invalid ->
        <<_byte, rest::binary>> = input
        pending = pending || {position, output_position}
        walk(rest, wire, position + 1, output_position + 1, output, pending, summary, config)

      {value, consumed, rest} ->
        case close_error(wire, position, output_position, output, pending, summary, config) do
          {:ok, output, summary} ->
            {output, output_position} =
              if value == :ignored, do: {output, output_position},
                else: {[value | output], output_position + 1}
            walk(rest, wire, position + consumed, output_position, output, nil, summary, config)

          {:error, _reason} = error -> error
        end
    end
  end

  defp close_error(_wire, _position, _output_position, output, nil, summary, _config),
    do: {:ok, output, summary}

  defp close_error(wire, position, output_position, output, {start, output_start}, summary, config) do
    length = position - start
    bytes = binary_part(wire, start, length)
    event = %{input_offset: config.input_base + start, output_offset: output_start,
      input_length: length, output_length: output_position - output_start, bytes: bytes}

    case config.on_error.(event) do
      :ok -> {:ok, [bytes | output], %{invalid_events: summary.invalid_events + 1,
        invalid_bytes: summary.invalid_bytes + length}}
      {:error, _reason} = error -> error
      other -> raise ArgumentError, "on_error must return :ok or {:error, reason}, got: #{inspect(other)}"
    end
  end

  defp token(<<32, rest::binary>>, %{spaces: true}), do: {32, 1, rest}
  defp token(<<byte, rest::binary>>, %{strip_whitespace: true}) when byte in [32, 9, 13, 10],
    do: {:ignored, 1, rest}

  # Exact binary-prefix clauses never parse UTF-8 or skip a guessed scalar size.
  for {glyph, byte} <- @glyph_to_byte do
    defp token(<<unquote(glyph), rest::binary>>, _config),
      do: {unquote(byte), unquote(byte_size(glyph)), rest}
  end

  defp token(_input, _config), do: :invalid

  @doc ~S'''
  The `~PB` sigil: decodes printable-binary content to a raw binary at compile
  time. Use `"..."` or a `"""` heredoc (a literal `"` never appears in the
  payload, so it can't close the sigil early).

      iex> import PrintableBinary
      iex> ~PB"AB"
      "AB"
  '''
  defmacro sigil_PB({:"<<>>", _meta, [string]}, _modifiers) when is_binary(string) do
    decode_strict!(string, strip_whitespace: true)
  end
end

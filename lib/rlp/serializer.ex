defmodule RLP.Serializer do
  defmacro serialize(fields) do
    do_serialize(:default, fields)
  end

  defmacro serialize(type, fields) do
    do_serialize(type, fields)
  end

  defp do_serialize(type, fields) do
    to_list_type = :"rlp_#{type}"

    quote do
      def to_list(%__MODULE__{} = record, [type: unquote(to_list_type)] = _options) do
        unquote(fields)
        |> Enum.map(&Map.get(record, elem(&1, 0)))
      end

      def from_list(list, [type: unquote(to_list_type)] = options) do
        attributes =
          unquote(fields)
          |> Enum.with_index()
          |> Enum.map(fn {{field_name, field_type}, field_idx} = _field ->
            raw_field_value = Enum.at(list, field_idx)

            field_value =
              case field_type do
                :unsigned -> :binary.decode_unsigned(raw_field_value)
                _ -> raw_field_value
              end

            {field_name, field_value}
          end)

        record = struct(__MODULE__, attributes)
        %{record | hash: RLP.Hash.hex(record, options)}
      end

      unless Module.defines?(__MODULE__, {:to_rlp, 2}) do
        def to_rlp(%__MODULE__{} = record, options \\ []) do
          options = if options[:type], do: options, else: [type: :rlp_default] ++ options
          do_to_rlp(record, Map.new(options))
        end
      end

      unless Module.defines?(__MODULE__, {:from_rlp, 2}) do
        def from_rlp(rlp, options \\ []) do
          options = if options[:type], do: options, else: [type: :rlp_default] ++ options
          do_from_rlp(rlp, Map.new(options))
        end
      end

      defp do_to_rlp(%__MODULE__{} = record, %{type: unquote(type)} = options),
        do: do_to_rlp(record, %{options | type: unquote(to_list_type)})

      defp do_to_rlp(%__MODULE__{} = record, %{type: unquote(to_list_type)} = options),
        do: ExRLP.encode(record, Map.to_list(options))

      defp do_from_rlp(rlp, %{type: unquote(type)} = options),
        do: do_from_rlp(rlp, %{options | type: unquote(to_list_type)})

      defp do_from_rlp(rlp, %{type: unquote(to_list_type)} = options),
        do: ExRLP.decode(rlp, Map.to_list(options)) |> from_list(type: options[:type])
    end
  end

  defmacro __using__(_opts) do
    quote do
      import RLP.Serializer, only: [serialize: 1, serialize: 2]

      defimpl ExRLP.Encode, for: __MODULE__ do
        alias ExRLP.Encode

        def encode(record, options \\ []) do
          module_name =
            __MODULE__
            |> Module.split()
            |> Enum.drop(3)
            |> Enum.join(".")

          type =
            case Atom.to_string(options[:type]) do
              "nil" -> :rlp_default
              "rlp_" <> type -> :"rlp_#{type}"
              type -> :"rlp_#{type}"
            end

          record
          |> :"Elixir.CredoCoreNode.#{module_name}".to_list(type: type)
          |> Encode.encode(options)
        end
      end

      defimpl RLP.Hash, for: __MODULE__ do
        def binary(record, options \\ []) do
          record
          |> ExRLP.encode(type: options[:type], encoding: :hex)
          |> :libsecp256k1.sha256()
        end

        def hex(record, options \\ []) do
          record
          |> binary(options)
          |> Base.encode16()
        end
      end
    end
  end
end

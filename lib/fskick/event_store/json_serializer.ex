defmodule Fskick.EventStore.JsonSerializer do
  @moduledoc """
  JSON serializer that loads the event struct module on demand before
  decoding, and transparently crypto-shreds PII fields.

  ## On-demand module loading

  The default `EventStore.JsonSerializer` calls
  `Jason.decode!(binary, keys: :atoms!)`, which fails when any JSON key
  has not yet been interned as an atom in the VM. Atoms become interned
  when the module that references them is loaded, but BEAM module
  loading is lazy and the `EventStore.Subscriptions.SubscriptionFsm`
  process that runs deserialize/2 is started before any projector's
  `project/3` clause has executed — so on cold boot the first read of a
  fresh event type crashes.

  This serializer calls `Code.ensure_loaded!/1` on the event struct
  module before decoding. The struct's field atoms are interned during
  module load, so the strict-atoms decode always succeeds.

  ## Crypto-shredding

  Events that implement the `Fskick.PII` protocol declare a `key_field`
  (holding the per-user crypto key id) and a list of PII `fields`. On
  serialize those fields are encrypted under the user's key; on deserialize
  they are decrypted. If the key has been deleted (the user was forgotten),
  decryption fails and the field is replaced with a `#{inspect("[redacted]")}`
  tombstone — the ciphertext in the event store is then unrecoverable.
  """

  @behaviour EventStore.Serializer

  alias Fskick.PII
  alias Fskick.Users.Crypto

  @tombstone "[redacted]"

  @impl true
  def serialize(term) do
    term
    |> encrypt_pii()
    |> Jason.encode!()
  end

  @impl true
  def deserialize(binary, config) do
    case Keyword.get(config, :type) do
      nil ->
        Jason.decode!(binary)

      type ->
        module = String.to_existing_atom(type)
        Code.ensure_loaded!(module)

        module
        |> struct(Jason.decode!(binary, keys: :atoms!))
        |> decrypt_pii()
    end
  end

  defp encrypt_pii(term) do
    transform_pii(term, fn key_id, field, value ->
      case Crypto.encrypt(key_id, value) do
        {:ok, encrypted} ->
          encrypted

        :error ->
          raise "cannot encrypt PII field #{inspect(field)}: no crypto key for #{inspect(key_id)}"
      end
    end)
  end

  defp decrypt_pii(term) do
    transform_pii(term, fn key_id, _field, value ->
      case Crypto.decrypt(key_id, value) do
        {:ok, plaintext} -> plaintext
        :error -> @tombstone
      end
    end)
  end

  defp transform_pii(term, fun) when is_struct(term) do
    case PII.impl_for(term) do
      nil ->
        term

      _impl ->
        %{key_field: key_field, fields: fields} = PII.spec(term)
        key_id = Map.fetch!(term, key_field)

        Enum.reduce(fields, term, fn field, acc ->
          Map.update!(acc, field, &fun.(key_id, field, &1))
        end)
    end
  end

  defp transform_pii(term, _fun), do: term
end

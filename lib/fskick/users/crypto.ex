defmodule Fskick.Users.Crypto do
  @moduledoc """
  Per-user symmetric encryption backing crypto-shredding of PII.

  Each user has a 256-bit key stored in the `user_crypto_keys` table
  (`Fskick.Repo`). PII fields are encrypted with AES-256-GCM under that key
  before being persisted in the event store. To "forget" a user we delete
  their key (`delete_key/1`): every event still exists, but the encrypted PII
  becomes permanently unrecoverable ciphertext.

  This is deliberately a plain operational store, not event-sourced — the keys
  are the one thing that must be genuinely deletable.
  """

  import Ecto.Query, only: [from: 2]

  alias Fskick.Repo
  alias Fskick.Users.CryptoKey

  @key_bytes 32
  @iv_bytes 12
  @tag_bytes 16
  @aad "fskick-pii"

  @doc """
  Generate and persist a new random key for `user_id`. Call once per user
  (during registration); a duplicate key insert returns an error changeset.
  """
  def generate_key(user_id) do
    %CryptoKey{user_id: user_id, key: :crypto.strong_rand_bytes(@key_bytes)}
    |> Repo.insert()
    |> case do
      {:ok, _} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Encrypt `plaintext` for `user_id`. Returns `{:ok, base64}` where the payload
  is `Base.encode64(iv <> tag <> ciphertext)`, or `:error` if the user has no
  key (already forgotten). `nil` plaintext passes through as `{:ok, nil}`.
  """
  def encrypt(_user_id, nil), do: {:ok, nil}

  def encrypt(user_id, plaintext) when is_binary(plaintext) do
    case fetch_key(user_id) do
      nil ->
        :error

      key ->
        iv = :crypto.strong_rand_bytes(@iv_bytes)

        {ciphertext, tag} =
          :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, @aad, true)

        {:ok, Base.encode64(iv <> tag <> ciphertext)}
    end
  end

  @doc """
  Decrypt a payload produced by `encrypt/2` for `user_id`. Returns
  `{:ok, plaintext}`, or `:error` if the key is gone (forgotten) or the
  payload fails authentication. `nil` passes through as `{:ok, nil}`.
  """
  def decrypt(_user_id, nil), do: {:ok, nil}

  def decrypt(user_id, payload) when is_binary(payload) do
    with key when not is_nil(key) <- fetch_key(user_id),
         {:ok, <<iv::binary-size(@iv_bytes), tag::binary-size(@tag_bytes), ciphertext::binary>>} <-
           Base.decode64(payload),
         plaintext when is_binary(plaintext) <-
           :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, @aad, tag, false) do
      {:ok, plaintext}
    else
      _ -> :error
    end
  end

  @doc "Permanently delete the user's key — the crypto-shredding operation."
  def delete_key(user_id) do
    {count, _} = Repo.delete_all(from k in CryptoKey, where: k.user_id == ^user_id)
    {:ok, count}
  end

  defp fetch_key(user_id) do
    case Repo.get(CryptoKey, user_id) do
      nil -> nil
      %CryptoKey{key: key} -> key
    end
  end
end

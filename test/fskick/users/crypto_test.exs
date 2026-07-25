defmodule Fskick.Users.CryptoTest do
  use Fskick.DataCase

  alias Fskick.Users.Crypto

  setup do
    %{user_id: Ecto.UUID.generate()}
  end

  describe "encrypt/2 and decrypt/2" do
    test "round-trips a value through the user's key", %{user_id: user_id} do
      :ok = Crypto.generate_key(user_id)

      assert {:ok, ciphertext} = Crypto.encrypt(user_id, "alice@example.com")
      assert ciphertext != "alice@example.com"
      assert {:ok, "alice@example.com"} = Crypto.decrypt(user_id, ciphertext)
    end

    test "produces different ciphertext each time (random IV)", %{user_id: user_id} do
      :ok = Crypto.generate_key(user_id)

      {:ok, a} = Crypto.encrypt(user_id, "same")
      {:ok, b} = Crypto.encrypt(user_id, "same")

      assert a != b
      assert {:ok, "same"} = Crypto.decrypt(user_id, a)
      assert {:ok, "same"} = Crypto.decrypt(user_id, b)
    end

    test "nil passes through untouched", %{user_id: user_id} do
      :ok = Crypto.generate_key(user_id)
      assert {:ok, nil} = Crypto.encrypt(user_id, nil)
      assert {:ok, nil} = Crypto.decrypt(user_id, nil)
    end

    test "encrypt returns :error without a key", %{user_id: user_id} do
      assert :error = Crypto.encrypt(user_id, "secret")
    end
  end

  describe "delete_key/1 (crypto-shredding)" do
    test "makes previously-encrypted data unrecoverable", %{user_id: user_id} do
      :ok = Crypto.generate_key(user_id)
      {:ok, ciphertext} = Crypto.encrypt(user_id, "alice@example.com")

      assert {:ok, 1} = Crypto.delete_key(user_id)
      assert :error = Crypto.decrypt(user_id, ciphertext)
    end

    test "another user's key cannot decrypt this user's data", %{user_id: user_id} do
      other = Ecto.UUID.generate()
      :ok = Crypto.generate_key(user_id)
      :ok = Crypto.generate_key(other)

      {:ok, ciphertext} = Crypto.encrypt(user_id, "alice@example.com")
      assert :error = Crypto.decrypt(other, ciphertext)
    end
  end
end

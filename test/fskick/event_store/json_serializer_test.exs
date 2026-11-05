defmodule Fskick.EventStore.JsonSerializerTest do
  use Fskick.DataCase

  alias Fskick.EventStore.JsonSerializer
  alias Fskick.Users.Crypto
  alias Fskick.Users.Events.UserRegistered

  @type_config [type: "Elixir.Fskick.Users.Events.UserRegistered"]

  setup do
    user_id = Ecto.UUID.generate()
    :ok = Crypto.generate_key(user_id)
    %{user_id: user_id}
  end

  test "encrypts PII on serialize and decrypts on deserialize", %{user_id: user_id} do
    event = %UserRegistered{
      user_id: user_id,
      player_id: Ecto.UUID.generate(),
      email: "alice@example.com",
      hashed_password: "$argon2id$hash"
    }

    json = JsonSerializer.serialize(event)

    # Email is ciphertext at rest; hashed_password stays cleartext.
    decoded = Jason.decode!(json)
    refute decoded["email"] == "alice@example.com"
    assert decoded["hashed_password"] == "$argon2id$hash"
    assert decoded["user_id"] == user_id

    # Round-trips back to cleartext.
    assert %UserRegistered{email: "alice@example.com", hashed_password: "$argon2id$hash"} =
             JsonSerializer.deserialize(json, @type_config)
  end

  test "tombstones the PII field when the key is gone (forgotten user)", %{user_id: user_id} do
    event = %UserRegistered{
      user_id: user_id,
      player_id: Ecto.UUID.generate(),
      email: "alice@example.com",
      hashed_password: "$argon2id$hash"
    }

    json = JsonSerializer.serialize(event)
    {:ok, _} = Crypto.delete_key(user_id)

    assert %UserRegistered{email: "[redacted]", hashed_password: "$argon2id$hash"} =
             JsonSerializer.deserialize(json, @type_config)
  end

  test "leaves non-PII events untouched" do
    event = %Fskick.Players.Events.PlayerCreated{player_id: Ecto.UUID.generate(), name: "Bob"}
    json = JsonSerializer.serialize(event)

    assert Jason.decode!(json)["name"] == "Bob"

    assert %Fskick.Players.Events.PlayerCreated{name: "Bob"} =
             JsonSerializer.deserialize(json, type: "Elixir.Fskick.Players.Events.PlayerCreated")
  end
end

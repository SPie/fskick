defmodule Fskick.Users.EmailTest do
  use ExUnit.Case, async: true

  import Fskick.DataCase, only: [errors_on: 1]

  alias Fskick.Users.Email

  # "@example.com" is 12 characters, so this many "a"s make 160 in total.
  @max_local_part 148

  defp validate(email) do
    {%{}, %{email: :string}}
    |> Ecto.Changeset.cast(%{email: email}, [:email])
    |> Email.validate()
  end

  describe "normalize/1" do
    test "trims surrounding whitespace" do
      assert Email.normalize("  alice@example.com \n") == "alice@example.com"
    end

    test "downcases" do
      assert Email.normalize("Alice@Example.COM") == "alice@example.com"
    end

    test "passes nil through" do
      assert Email.normalize(nil) == nil
    end
  end

  describe "validate/1" do
    test "accepts well-formed emails" do
      for email <- ["alice@example.com", "a.b+tag@sub.example.co.uk", "x@y.z"] do
        assert %Ecto.Changeset{valid?: true} = validate(email)
      end
    end

    test "rejects malformed emails" do
      for email <- [
            "alice",
            "alice@example",
            "@example.com",
            "alice@.com",
            "al ice@example.com",
            "alice@exa mple.com"
          ] do
        assert %{email: ["must be a valid email"]} = errors_on(validate(email)),
               "expected #{inspect(email)} to be rejected"
      end
    end

    test "accepts an email of exactly 160 characters" do
      email = String.duplicate("a", @max_local_part) <> "@example.com"

      assert String.length(email) == 160
      assert %Ecto.Changeset{valid?: true} = validate(email)
    end

    test "rejects an email of 161 characters" do
      email = String.duplicate("a", @max_local_part + 1) <> "@example.com"

      assert %{email: ["should be at most 160 character(s)"]} = errors_on(validate(email))
    end

    test "leaves a missing email to validate_required" do
      assert %Ecto.Changeset{valid?: true} = validate(nil)
    end
  end
end

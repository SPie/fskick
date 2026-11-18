defmodule Fskick.Users.Commands.ChangeUserEmailTest do
  use Fskick.DataCase

  import Fskick.UsersFixtures

  alias Fskick.Users.Commands.ChangeUserEmail

  defp new(email), do: ChangeUserEmail.new(%{user_id: Ecto.UUID.generate(), email: email})

  describe "new/1" do
    test "returns a command with valid attrs" do
      id = Ecto.UUID.generate()

      assert {:ok, %ChangeUserEmail{user_id: ^id, email: "alice@example.com"}} =
               ChangeUserEmail.new(%{user_id: id, email: "alice@example.com"})
    end

    test "normalizes the email" do
      assert {:ok, %ChangeUserEmail{email: "alice@example.com"}} = new("  Alice@Example.COM ")
    end

    test "rejects missing user_id" do
      assert {:error, changeset} = ChangeUserEmail.new(%{email: "alice@example.com"})
      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "rejects a blank email" do
      for email <- [nil, "", "   "] do
        assert {:error, changeset} = new(email)
        assert "can't be blank" in errors_on(changeset).email
      end
    end

    test "rejects a malformed email" do
      for email <- ["alice", "alice@example", "@", "al ice@example.com"] do
        assert {:error, changeset} = new(email)
        assert "must be a valid email" in errors_on(changeset).email
      end
    end

    test "rejects an email over 160 characters" do
      assert {:error, changeset} = new(String.duplicate("a", 150) <> "@example.com")
      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "rejects an email taken by another user" do
      user_fixture(%{email: "alice@example.com"})

      assert {:error, changeset} = new("ALICE@example.com")
      assert "has already been taken" in errors_on(changeset).email
    end

    test "does not treat the user's own email as taken" do
      user = user_fixture(%{email: "alice@example.com"})

      assert {:ok, %ChangeUserEmail{}} =
               ChangeUserEmail.new(%{user_id: user.id, email: "alice@example.com"})
    end
  end
end

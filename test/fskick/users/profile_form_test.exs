defmodule Fskick.Users.ProfileFormTest do
  use Fskick.DataCase

  import Fskick.UsersFixtures

  alias Fskick.Players.Commands.RenamePlayer
  alias Fskick.Users.Commands.ChangeUserEmail
  alias Fskick.Users.Commands.ChangeUserPassword
  alias Fskick.Users.ProfileForm

  setup do
    %{user: user_fixture(%{email: "alice@example.com", player_name: "Alice"})}
  end

  defp params(overrides \\ %{}) do
    Map.merge(
      %{
        "email" => "alice@example.com",
        "player_name" => "Alice",
        "current_password" => "",
        "password" => "",
        "password_confirmation" => ""
      },
      overrides
    )
  end

  describe "changeset/3" do
    test "defaults to the current email and player name", %{user: user} do
      changeset = ProfileForm.changeset(user)

      assert get_field(changeset, :email) == "alice@example.com"
      assert get_field(changeset, :player_name) == "Alice"
    end
  end

  describe "commands/3 with email and player name" do
    test "builds nothing when nothing changed", %{user: user} do
      assert {:ok, []} = ProfileForm.commands(user, params())
    end

    test "treats values equal after normalisation as unchanged", %{user: user} do
      attrs = params(%{"email" => " ALICE@example.com ", "player_name" => " Alice "})

      assert {:ok, []} = ProfileForm.commands(user, attrs)
    end

    test "builds only the email command for a new email", %{user: user} do
      user_id = user.id

      assert {:ok, [%ChangeUserEmail{user_id: ^user_id, email: "new@example.com"}]} =
               ProfileForm.commands(user, params(%{"email" => "new@example.com"}))
    end

    test "builds only the rename command for a new name", %{user: user} do
      player_id = user.player.id

      assert {:ok, [%RenamePlayer{player_id: ^player_id, name: "Alicia"}]} =
               ProfileForm.commands(user, params(%{"player_name" => "Alicia"}))
    end

    test "maps the name error onto player_name", %{user: user} do
      user_fixture(%{player_name: "Bob"})

      assert {:error, changeset} =
               ProfileForm.commands(user, params(%{"player_name" => "Bob"}))

      assert %{player_name: ["has already been taken"]} = errors_on(changeset)
    end

    test "rejects blank values", %{user: user} do
      for blank <- ["", "   "] do
        assert {:error, changeset} =
                 ProfileForm.commands(user, params(%{"email" => blank, "player_name" => blank}))

        assert %{email: ["can't be blank"], player_name: ["can't be blank"]} =
                 errors_on(changeset)
      end
    end
  end

  describe "commands/3 with passwords" do
    @filled %{
      "current_password" => "hello world!",
      "password" => "a new password",
      "password_confirmation" => "a new password"
    }

    test "builds the password command when all fields are valid", %{user: user} do
      assert {:ok, [%ChangeUserPassword{}]} =
               ProfileForm.commands(user, params(@filled))
    end

    test "requires the others when any single field is filled", %{user: user} do
      for {field, value} <- @filled do
        assert {:error, changeset} = ProfileForm.commands(user, params(%{field => value}))

        others = @filled |> Map.delete(field) |> Map.keys()
        errors = errors_on(changeset)

        for other <- others do
          assert errors[String.to_existing_atom(other)] == ["can't be blank"]
        end
      end
    end

    test "does not skip a whitespace-only field", %{user: user} do
      assert {:error, changeset} =
               ProfileForm.commands(user, params(%{"password" => "   "}))

      assert %{current_password: ["can't be blank"], password: ["can't be blank"]} =
               errors_on(changeset)
    end

    test "reports a wrong current password", %{user: user} do
      attrs = params(%{@filled | "current_password" => "wrong"})

      assert {:error, changeset} = ProfileForm.commands(user, attrs)
      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end
  end

  describe "commands/3 with everything changed" do
    test "applies the rename, then the email, then the password", %{user: user} do
      attrs =
        Map.merge(@filled, %{"email" => "new@example.com", "player_name" => "Alicia"})

      assert {:ok, [%RenamePlayer{}, %ChangeUserEmail{}, %ChangeUserPassword{}]} =
               ProfileForm.commands(user, params(attrs))
    end

    test "collects the errors of every field", %{user: user} do
      user_fixture(%{player_name: "Bob"})

      attrs =
        params(%{"email" => "nope", "player_name" => "Bob", "password" => "a new password"})

      assert {:error, changeset} = ProfileForm.commands(user, attrs)

      assert %{
               email: ["must be a valid email"],
               player_name: ["has already been taken"],
               current_password: ["can't be blank"],
               password_confirmation: ["can't be blank"]
             } = errors_on(changeset)
    end
  end
end

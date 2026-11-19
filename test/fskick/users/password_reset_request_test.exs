defmodule Fskick.Users.PasswordResetRequestTest do
  use Fskick.DataCase, async: true

  alias Fskick.Users.PasswordResetRequest

  describe "new/1" do
    test "normalises a well-formed email" do
      assert {:ok, %PasswordResetRequest{email: "alice@example.com"}} =
               PasswordResetRequest.new(%{"email" => "  Alice@Example.com "})
    end

    test "requires an email" do
      assert {:error, changeset} = PasswordResetRequest.new(%{"email" => " "})
      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects a malformed email" do
      assert {:error, changeset} = PasswordResetRequest.new(%{"email" => "nope"})
      assert %{email: ["must be a valid email"]} = errors_on(changeset)
    end
  end
end

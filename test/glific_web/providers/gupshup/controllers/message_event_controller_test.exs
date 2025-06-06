defmodule GlificWeb.Providers.Gupshup.Controllers.MessageEventControllerTest do
  use GlificWeb.ConnCase

  alias Glific.{
    Contacts,
    Messages,
    Seeds.SeedsDev
  }

  @message_event_request_params %{
    "app" => "Glific App",
    "payload" => %{
      "destination" => "1234567851",
      "gsId" => "853bab23-0963-42c7-8436-7fe4f5866c76",
      "id" => "gBEGkZkXRDmUAgl5FpzpjNgI5Co",
      "payload" => %{
        "ts" => 1_592_311_836
      }
    },
    "timestamp" => 1_592_311_842_070,
    "type" => "message-event",
    "version" => 2
  }

  setup do
    default_provider = SeedsDev.seed_providers()
    SeedsDev.seed_organizations(default_provider)
    SeedsDev.seed_contacts()
    SeedsDev.seed_messages()
    :ok
  end

  describe "handler" do
    test "handler should return nil data", %{conn: conn} do
      conn = post(conn, "/gupshup", @message_event_request_params)
      assert response(conn, 200) == ""
    end
  end

  describe "status" do
    setup %{conn: conn} do
      gupshup_id = Faker.String.base64(36)

      message_params =
        @message_event_request_params
        |> put_in(["payload", "type"], "enqueued")
        |> put_in(["payload", "id"], Faker.String.base64(36))
        |> put_in(["payload", "gsId"], gupshup_id)
        |> put_in(["payload", "payload"], %{"ts" => "1592311836"})

      [message | _] =
        Messages.list_messages(%{filter: %{organization_id: conn.assigns[:organization_id]}})

      Messages.update_message(message, %{bsp_message_id: gupshup_id})
      %{message_params: message_params, message: message}
    end

    test "enqueued status should update the message status", setup_config = %{conn: conn} do
      # when message enqueued
      success_conn = post(conn, "/gupshup", setup_config.message_params)
      response(success_conn, 200)
      message = Messages.get_message!(setup_config.message.id)
      assert message.bsp_status == :enqueued

      # when message sent
      message_params = put_in(setup_config.message_params, ["payload", "type"], "sent")
      sent_conn = post(conn, "/gupshup", message_params)
      response(sent_conn, 200)
      message = Messages.get_message!(setup_config.message.id)
      assert message.bsp_status == :sent

      # when message read
      message_params = put_in(setup_config.message_params, ["payload", "type"], "read")
      read_conn = post(conn, "/gupshup", message_params)
      response(read_conn, 200)
      message = Messages.get_message!(setup_config.message.id)
      assert message.bsp_status == :read

      # when message delivered
      message_params = put_in(setup_config.message_params, ["payload", "type"], "delivered")
      delivered_conn = post(conn, "/gupshup", message_params)
      response(delivered_conn, 200)
      message = Messages.get_message!(setup_config.message.id)
      assert message.bsp_status == :delivered

      # when message failed with no code
      message_params = put_in(setup_config.message_params, ["payload", "type"], "failed")
      failed_conn = post(conn, "/gupshup", message_params)
      response(failed_conn, 200)
      message = Messages.get_message!(setup_config.message.id)
      assert message.bsp_status == :error
      assert message.errors != nil
      assert message.errors != %{}

      # when message failed with code 1002 (bad phone number)
      message_params =
        setup_config.message_params
        |> put_in(["payload", "type"], "failed")
        |> put_in(["payload", "payload"], %{"ts" => "1592311836", "code" => 1002})

      failed_conn = post(conn, "/gupshup", message_params)
      response(failed_conn, 200)
      message = Messages.get_message!(setup_config.message.id)
      assert message.bsp_status == :error
      assert message.errors != nil
      assert message.errors != %{}

      contact = Contacts.get_contact!(message.contact_id)
      assert contact.status == :invalid
      assert contact.optout_method == "Number does not exist"
    end
  end
end

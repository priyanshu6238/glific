defmodule Glific.Clients.Bandhu do
  @moduledoc """
  Tweak GCS Bucket name based on group that the contact is in (if any)
  """

  import Ecto.Query, warn: false

  alias Glific.Clients.CommonWebhook

  @housing_url "https://housing.bandhumember.work/api/housing/create_sql_glific_query"

  @doc """
  Create a webhook with different signatures, so we can easily implement
  additional functionality as needed
  """
  @spec webhook(String.t(), map()) :: map()
  def webhook("mock_bandhu_for_profile_check", _fields) do
    %{
      profile_count: 0,
      profiles: []
    }
  end

  def webhook("fetch_user_profiles", fields) do
    profile_count =
      get_in(fields, ["results", "parent", "bandhu_profile_check_mock", "data", "profile_count"]) ||
        0

    profiles =
      get_in(fields, ["results", "parent", "bandhu_profile_check_mock", "data", "profiles"]) ||
        nil

    {index_map, message_list} =
      if is_nil(profiles),
        do: {%{}, ["No profiles found"]},
        else: format_profile_message(profiles)

    %{
      profile_selection_message: Enum.join(message_list, "\n"),
      index_map: Jason.encode!(index_map),
      profile_count: profile_count,
      x_api_key: "nothing"
    }
  end

  def webhook("set_contact_profile", fields) do
    index_map = Jason.decode!(fields["index_map"])
    profile_number = fields["profile_number"]

    if Map.has_key?(index_map, profile_number) do
      profile = index_map[profile_number]
      %{profile: profile, is_valid: true}
    else
      %{profile: %{}, is_valid: false}
    end
  end

  def webhook("test", _fields),
    do: %{
      "media_url" =>
        "https://www.google.com/images/branding/googlelogo/2x/googlelogo_color_272x92dp.png"
    }

  def webhook("speech_to_text_with_bhasini", fields),
    do: CommonWebhook.webhook("speech_to_text_with_bhasini", fields)

  def webhook("housing_sql", fields) do
    header = [{"Content-Type", "application/json"}]

    cleaned_fields = clean_fields(fields)

    Tesla.post(@housing_url, Jason.encode!(cleaned_fields), headers: header)
    |> case do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        Jason.decode!(body)
        |> handle_response()
        |> Map.merge(%{success: true})

      {_status, _response} ->
        %{success: false, response: "Error response received"}
    end
  end

  def webhook(_, _fields), do: %{}

  @spec handle_response(map()) :: map()
  defp handle_response(%{"success" => "false"} = response),
    do: %{success: false, message: response["message"]}

  defp handle_response(response), do: response

  @spec clean_fields(map()) :: map()
  defp clean_fields(fields) do
    Enum.reduce(fields, %{}, fn {key, value}, acc ->
      if do_clean_fields(key, value),
        do: Map.put(acc, key, ""),
        else: Map.put(acc, key, value)
    end)
  end

  @spec do_clean_fields(String.t(), String.t()) :: boolean()
  defp do_clean_fields(key, value) when is_binary(value),
    do: String.match?(value, ~r/@results\..*?\.#{key}/)

  defp do_clean_fields(_key, _value), do: false

  defp format_profile_message(profiles) do
    profiles
    |> Enum.reduce({%{}, []}, fn {index, profile}, {index_map, message_list} ->
      profile_name = profile["name"]
      user_roles = profile["user_roles"]["role_type"]

      {
        Map.put(index_map, index, profile),
        message_list ++ ["Type *#{index}* for #{profile_name} (#{user_roles})"]
      }
    end)
  end
end

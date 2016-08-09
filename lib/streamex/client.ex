defmodule Streamex.Client do
  use HTTPoison.Base
  alias Streamex.{Request, Config}
  alias Timex.DateTime, as: DateTime
  alias Streamex.Token

  def prepare_request(%Request{} = req) do
    uri = URI.merge(Config.base_url, req.path)
    query = Map.merge(req.params, %{"api_key" => Config.key}) |> URI.encode_query
    uri = %{uri | query: query}
    %{req | url: to_string(uri)}
  end

  def sign_request(%Request{} = req) do
    case req.token do
      nil -> sign_request_with_key_secret(req, Config.key, Config.secret)
      _ -> sign_request_with_token(req, Config.secret)
    end
  end

  def execute_request(%Request{} = req) do
    request(
      req.method,
      req.url,
      req.body,
      req.headers,
      req.options
    )
  end

  def parse_response({:error, body}), do: {:error, body}
  def parse_response({:ok, response}) do
    Poison.decode!(response.body)
  end

  defp sign_request_with_token(%Request{} = req, secret) do
    token = Token.compact(req.token, secret)

    headers = [
      {"Authorization", token},
      {"stream-auth-type", "jwt"},
    ] ++ req.headers
    %{req | headers: headers}
  end

  defp sign_request_with_key_secret(%Request{} = req, key, secret) do
    algoritm = "hmac-sha256"
    {_, now} = DateTime.local() |> Timex.format("{RFC822}")

    api_key_header = {"X-Api-Key", key}
    date_header = {"Date", now}
    headers_value = "date"
    header_field_string = "#{headers_value}: #{now}"
    signature = :crypto.hmac(:sha256, secret, header_field_string) |> Base.encode64
    auth_header = {"Authorization", "Signature keyId=\"#{key}\",algorithm=\"#{algoritm}\",headers=\"#{headers_value}\",signature=\"#{signature}\""}

    headers = [api_key_header, date_header, auth_header] ++ req.headers
    %{req | headers: headers}
  end
end

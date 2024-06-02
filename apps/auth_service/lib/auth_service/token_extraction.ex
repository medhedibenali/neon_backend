defmodule AuthService.TokenExtraction do
  alias AuthService.Guardian

  def fetch_id_from_conn(conn) do
    token = fetch_token_from_headers(conn.req_headers)
    get_id_from_token(token)
  end

  defp fetch_token_from_headers(array) do
    obj =
      Enum.find(array, fn element ->
        match?({"authorization", _}, element)
      end)

    {"authorization", string} = obj
    pattern = ~r/Bearer\s+([A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+)/

    # Extract the token
    case Regex.run(pattern, string) do
      [_, token] ->
        token

      _ ->
        IO.puts("No match found")
    end
  end

  defp get_id_from_token(token) do
    {:ok, claims} =
      Guardian.decode_and_verify(token)

    claims["sub"]
  end
end

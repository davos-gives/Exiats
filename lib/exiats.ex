defmodule Exiats do
  @moduledoc """
  Iats/1STPay gateway implementation.

  The following features of their API are currently implemented:

  | Action                       | Method        |
  | ------                       | ------        |
  | authorize                    | `authorize/1` |
  | authorize_with_cryptogram    | `authorize_with_cryptogram/2` |

  We're not PCI-DSS compliant!

  While the API allows us to use "Auth" directly with credit card information, we don't ever want to be doing that ourselves. Instead
  we are using their hosted payment form to generate a credit card cryptogram which we then pass into create.
  """

  @base_url "https://secure-v.goemerchant.com/secure/RestGW/Gateway/"

  use Exiats.Adapter, required_conf: [:merchant_key, :processor_id]

  alias Exiats.Owner

  import IEx

  @doc """

  Performs a pre-authorization operation.

  The authorization validates the card details with the banks, places a hold on the transaction amount in the bank and triggers any risk management that IATS is running. If these aren't resolved within a certain amount of time they expire (presumably? figure out the timing on this.)

  DO NOT USE THIS particular function - we do not want to deal with PCI compliance and dealing directly with credit cards numbers/dates. Only using this during testing.

  ## Example
  The following session shows how you would pre-authorize a payment of 10 dollars on sample card.

  iex> owner = %Owner{
        name: "Ian Knauer",
        street: "123 Fake Street",
        city: "Vancouver",
        province: "BC",
        country: "Canada",
        postal_code: "V3H4X9"
      }

  iex> Exiats.authorize("10.00", owner)
  """
  def authorize(amount, owner) do
    config = get_config()

    card = [
      {"cardNumber", "4539394673694021"},
      {"cardExpMonth", "06"},
      {"cardExpYear", "21"},
      {"transactionAmount", amount},
    ]

    params = card ++ owner_params(owner)
    commit(:post, "Transaction/Auth", params, config)
  end

  @doc """

  Performs a pre-authorization operation.

  The authorization validates the card details with the banks, places a hold on the transaction amount in the bank and triggers any risk management that IATS is running. If these aren't resolved within a certain amount of time they expire (presumably? figure out the timing on this.)

  this authorization uses the credit card cryptogram that is issued by the iFrame on donation forms. It takes the card, expiry and CVV and allows us to pass along string that doesn't require compliance on our end.

  Each cryptogram can only be used once (you get an error if you try submitting twice with the same) and expire after 15 mins.

  This is the only authorization we should be using.

  ## Example
  The following session shows how you would pre-authorize a payment of 10 dollars with a previously run

  iex> owner = %Owner{
        name: "Ian Knauer",
        street: "123 Fake Street",
        city: "Vancouver",
        province: "BC",
        country: "Canada",
        postal_code: "V3H4X9"
      }

  iex> Exiats.authorize("10.00", "A124000001IDBKS7VYA8CTLH", owner)

  """
  def authorize_with_cryptogram(amount, cardCrypto, owner) do
    config = get_config()

    params = [
      {"creditCardCryptogram", cardCrypto},
      {"transactionAmount", amount},
    ]


    commit(:post, "Transaction/Auth", params, config)
  end

  def settle(reference, amount) do
    config = get_config()

    params = [
      {"refNumber", reference},
      {"transactionAmount", amount}
    ]

    commit(:post, "Transaction/Settle", params, config)
  end

  defp commit(method, path, params, options) do

    headers = [
      {"Content-Type", "application/json"},
      {"charset", "utf-8"}
    ]

    credentials = [
      {"merchantKey", options[:merchant_key]},
      {"processorId", options[:processor_id]}
    ]

    response = HTTPoison.request(:post, "#{@base_url}#{path}", {:form, Enum.concat(params, credentials)}, headers)
    |> format_response
  end

  defp format_response(response) do
    case response do
      {:ok, %HTTPoison.Response{body: body}} -> body |> Poison.decode!()
      _ -> %{"error" => "Something went terribly wrong"}
    end
  end

  defp get_config() do
    global_config = Application.get_env(:exiats, :global_config)
  end

  defp owner_params(%Owner{} = owner) do
    [
      {"ownerName", owner.name},
      {"ownerStreet", owner.street},
      {"ownerCity", owner.city},
      {"ownerState", owner.province},
      {"ownerCountry", owner.country},
      {"ownerZip", owner.postal_code}
    ]
  end

  defp owner_params(_), do: []
end

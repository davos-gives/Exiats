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
  alias Exiats.Ongoing
  alias Exiats.OngoingChanges

  import IEx

  @doc """

  Performs a pre-authorization operation.

  The authorization validates the card details with the banks, places a hold on the transaction amount in the bank and triggers any risk management that IATS is running. If these aren't resolved within a certain amount of time they expire (presumably? figure out the timing on this.)

  DO NOT USE THIS particular function - we do not want to deal with PCI compliance and dealing directly with credit cards numbers/dates. Only using this during testing.

  IATS test card number for visa == "4539394673694021". Always returns a valid response. See the documentation for numbers with different returns.

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

  Each cryptogram can only be used once (you get an error if you try submitting twice with the same) and expires after 15 mins.

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

  @doc """

  Performs a pre-authorization operation with a recurring donor..


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

  iex> ongoing_details = %Ongoing{
         frequency: "monthly",
         start_date: "22",
         start_month: "03",
         start_year: "2019"
       }

  iex> Exiats.authorize_recurring("10.00", owner, ongoing_details)

    %{
    "action" => "Auth",
    "data" => %{
      "authCode" => "956252",
      "authResponse" => "Approved 956252",
      "avsResponse" => "",
      "cardType" => "Visa",
      "cvv2Response" => "",
      "isPartial" => false,
      "last4" => "4021",
      "maskedPan" => "453939******4021",
      "orderId" => "636888811600816019",
      "originalFullAmount" => 9.0,
      "partialAmountApproved" => 0.0,
      "partialId" => "",
      "referenceNumber" => "9032426",
      "token" => "1036111254504021"
    },
    "errorMessages" => [],
    "isError" => false,
    "isSuccess" => true,
    "validationFailures" => [],
    "validationHasFailed" => false
  }
  """

  def authorize_recurring(amount, owner, ongoing_options) do
    config = get_config()

    card = [
      {"cardNumber", "4539394673694021"},
      {"cardExpMonth", "06"},
      {"cardExpYear", "21"},
      {"transactionAmount", amount},
    ]

    params = card ++ owner_params(owner) ++ ongoing_params(ongoing_options)
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

  @doc """

    %{
      "action" => "Sale",
      "data" => %{
        "authCode" => "691155",
        "authResponse" => "Approved 691155",
        "avsResponse" => "U",
        "cardType" => "Visa",
        "cvv2Response" => "",
        "isPartial" => false,
        "last4" => "4021",
        "maskedPan" => "453939******4021",
        "orderId" => "636888832851870759",
        "originalFullAmount" => 1.25,
        "partialAmountApproved" => 0.0,
        "partialId" => "",
        "referenceNumber" => "9032478",
        "token" => "1036111254504021"
      },
      "errorMessages" => [],
      "isError" => false,
      "isSuccess" => true,
      "validationFailures" => [],
      "validationHasFailed" => false
    }
  """

  def sale(amount, owner, %Ongoing{} = ongoing) do
    config = get_config()

    details = [
      {"cardNumber", "4539394673694021"},
      {"cardExpMonth", "06"},
      {"cardExpYear", "21"},
      {"cVV", "123"},
      {"transactionAmount", amount},
      {"autoGenerateOrderId", true},
      {"orderIdIsUnique", true},
    ]

    params = details ++ owner_params(owner) ++ ongoing_params(ongoing)
    commit(:post, "Transaction/Sale", params, config)
  end

  def sale(amount, owner) do
    config = get_config()

    details = [
      {"cardNumber", "4539394673694021"},
      {"cardExpMonth", "06"},
      {"cardExpYear", "21"},
      {"cVV", "123"},
      {"transactionAmount", amount},
      {"autoGenerateOrderId", true},
      {"orderIdIsUnique", true},
    ]

    params = details ++ owner_params(owner)
    commit(:post, "Transaction/Sale", params, config)
  end

  def vault_sale(vault_key, amount, owner) do
    config = get_config()

    details = [
      {"transactionAmount", amount},
      {"vaultKey", vault_key},
      {"autoGenerateOrderId", true},
      {"orderIdIsUnique", true}
    ]

    params = details ++ owner_params(owner)
    commit(:post, "Transaction/SaleUsingVault", params, config)
  end

  def recurring_modify(reference_number, changes) do
    config = get_config()

    details = [
      {"referenceNumber", reference_number}
    ]

    params = details ++ ongoing_changes_params(changes)
    commit(:post, "Transaction/RecurringModify", params, config)
  end

  def add_credit_card() do
    config = get_config()

    card = [
      {"vaultKey", "123456789a!"},
      {"cardNumber", "4539394673694021"},
      {"cardExpMonth", "06"},
      {"cardExpYear", "21"},
      {"cardType", "Visa"}
    ]

    commit(:post, "Transaction/VaultCreateCCRecord", card, config)
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

  defp ongoing_params(%Ongoing{} = ongoing) do
    [
      {"recurring", ongoing.frequency},
      {"recurringStartDate", "#{ongoing.start_month}/" <> "#{ongoing.start_date}/" <> "#{ongoing.start_year}"},
      {"recurringEndDate", "01/01/2099"}
    ]
  end

  defp ongoing_changes_params(%OngoingChanges{} = ongoing) do
    [
      {"recurringType", ongoing.frequency},
      {"recurringAmount", ongoing.amount}
    ]
  end

  defp ongoing_params(_), do: []
end

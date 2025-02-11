defmodule Archethic.Networking do
  @moduledoc """
  Module defines networking configuration of the node.
  """

  alias __MODULE__.IPLookup
  alias __MODULE__.PortForwarding

  @ip_validate_regex ~r/(^0\.)|(^127\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^192\.168\.)/
  @doc """
  Provides current host IP address by leveraging the IP lookup provider.

  If there is some problems from the provider, fallback methods are used to fetch the IP

  Otherwise error will be thrown
  """
  @spec get_node_ip() :: :inet.ip_address()
  defdelegate get_node_ip, to: IPLookup

  @doc """
  Try to open the port from the configuration.

  If not possible try other random port. Otherwise assume the port is open

  A force parameter can be given to use a random port if the port publication doesn't work
  """
  @spec try_open_port(:inet.port_number(), boolean()) :: :inet.port_number()
  defdelegate try_open_port(port, force?), to: PortForwarding

  @doc ~S"""
  Filters private IP address ranges

  ## Example

      iex> Archethic.Networking.valid_ip?({0,0,0,0})
      false

      iex> Archethic.Networking.valid_ip?({127,0,0,1})
      false

      iex> Archethic.Networking.valid_ip?({192,168,1,1})
      false

      iex> Archethic.Networking.valid_ip?({10,10,0,1})
      false

      iex> Archethic.Networking.valid_ip?({172,16,0,1})
      false

      iex> Archethic.Networking.valid_ip?({54,39,186,147})
      true
  """
  @spec valid_ip?(:inet.ip_address()) :: boolean()
  def valid_ip?(ip) do
    case :inet.ntoa(ip) do
      {:error, :einval} ->
        false

      ip_str ->
        !Regex.match?(
          @ip_validate_regex,
          to_string(ip_str)
        )
    end
  end
end

defmodule ExSync.Shadow do
  defstruct doc: %{}, client_version: 0, server_version: 0

  @type t :: %__MODULE__{
    doc: Map.t,
    client_version: Integer.t,
    server_version: Integer.t
  }
end

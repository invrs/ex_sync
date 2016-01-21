defmodule ExSync.Shadow do
  defstruct doc: %{}, clientVersion: 0, serverVersion: 0
  @type t :: %__MODULE__{
    doc: Map.t,
    clientVersion: Integer.t,
    serverVersion: Integer.t
  }
end

defmodule ExSync.Store do
  @moduledoc """
  Specification for Exsync Stores. Stores are being used to save and retrieve
  Server Documents
  """

  @type error :: atom

  use Behaviour

  @doc """
  Retrieves the document from the store by its ID.
  """
  defcallback get(String.t) :: Map.t

  @doc """
  Similarly to the Elixir `get_and_update/2` function (e.g. in Access, Agent,
  Doct, ...) this function gets the document from storage, applies a function
  to it and saves it back to the storage.

  **Reading and writing should be done in a transaction, as the document
  changing between the read and the write command will cause trouble that is
  extremely painful to track down.**
  """
  defcallback get_and_update(any, fun) :: {:ok | Map.t} | {:error | error}
end

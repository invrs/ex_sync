defmodule Exsync do
  require Logger

  alias Exsync.{Shadow, Edit, Storage}

  def diff_patch, do: Application.get_env(:exsync, :diff_patch)

  @moduledoc """
  This module implements the main parts of the server-side flow of the
  Diff Sync algorithm.
  """

  @type id :: any
  @type document :: map
  @type error :: (atom | map)

  @doc """
  The Diff Cycle. Takes changes from the client (can be empty) and
  """

  @spec sync_cycle(any, Shadow.t, Shadow.t, [Edit.t], Storage) ::
    {:ok, Shadow.t, [Edit.t]} | {:error, error}
  def sync_cycle(id, shadow, backup_shadow, edits, storage) do
    with {:ok, shadow}          <- patch_shadows(shadow, backup_shadow, edits),
         {:ok, doc}             <- patch_server_doc(storage, id, edits),
         {:ok, {shadow, edits}} <- get_server_doc_edits(shadow, doc),
    do:  {:ok, {put_in(shadow.doc, doc), edits}}
  end

  @doc """
  This function patches the server_shadow or backup_shadow with edits.

  Expects server_shadow and backup_shadow as type Exsync.Shadow,
  edits as a List of Exsync.Edit.
  """
  @spec patch_shadows(Shadow.t, Shadow.t, [Edit.t]) ::
    {:ok, Shadow.t} | {:error, error}
  def patch_shadows(server_shadow, backup_shadow, edits) do
    case apply_shadow_edits(server_shadow, backup_shadow, edits) do
      {:ok, {server_shadow, _backup_shadow}} ->
        # TODO: Fix logic around backup shadows
        {:ok, server_shadow}

      {:error, reason} ->
        Logger.error "Patching shadows failed: #{inspect reason}"
        {:error, reason}
    end
  end

  @doc """
  This function patches the server doc.

  It expects a storage adapter that implements the Exsync.Storage behaviour,
  an id and a list of edits as Exsync.Edit.

  It will use the `get_and_update/2` function of the storage, passing it a
  function to apply the edits to the server doc. That way we can use locks
  in the function to ensure data consistency between reading and writing.
  """
  @spec patch_server_doc(atom, any, [Edit.t]) ::
    {:ok, document} | {:error, error}
  def patch_server_doc(storage_adapter, id, edits) do
    storage_adapter.get_and_update(id, &apply_server_doc_edits(&1, edits))
  end

  @doc """
  Calculates the difference between the server shadow and the server doc.

  Returns the new edits as a list of one item as well as the server shadow with
  an updated server_version number (if applicable).
  """
  def get_server_doc_edits(server_shadow, doc) do
    case diff_patch.diff(server_shadow.doc, doc) do
      {:ok, diff} -> format_diff(diff, server_shadow)
      error       -> error
    end
  end

  @doc false
  defp format_diff(nil, server_shadow), do: {:ok, {server_shadow, []}}
  defp format_diff(diff, server_shadow) do
    diff = List.wrap %{
      diff: diff,
      serverVersion: server_shadow.server_version,
      localVersion: server_shadow.client_version
    }

    server_shadow = update_in server_shadow.server_version, &(&1 + 1)

    {:ok, {server_shadow, diff}}
  end

  @doc false
  defp apply_server_doc_edits(doc, [edit | edits]) do
    case diff_patch.patch(doc, edit["diff"]) do
      # Patch succesfull
      {:ok, new_doc} ->
        apply_server_doc_edits new_doc, edits

      # Patch failed, throwing away (Chapter 3 list step f)
      {:error, _reason} ->
        apply_server_doc_edits doc, edits
    end
  end
  defp apply_server_doc_edits(doc, []), do: {:ok, doc}

  @doc false
  defp apply_shadow_edits(server_shadow, backup_shadow, [edit | edits]) do
    cond do
      # Ideal, we are on the same page:
      server_shadow.server_version == edit["serverVersion"] ->
        do_apply_shadow_edits(server_shadow, backup_shadow, [edit | edits])

      # Not so ideal, previous edits were lost but we still have a backup:
      backup_shadow.server_version == edit["serverVersion"] ->
        do_apply_shadow_edits(backup_shadow, backup_shadow, [edit | edits])

      # Nope, we no longer have that server version you are talking about
      true ->
        {:error, %{
          reason: :no_matching_server_version,
          shadow_server_version: server_shadow.server_version,
          backup_server_version: backup_shadow.server_version,
          client_server_version: edit["serverVersion"],
          edit: edit
        }}
    end
  end
  defp apply_shadow_edits(server_shadow, backup_shadow, []) do
    {:ok, {server_shadow, backup_shadow}}
  end

  @doc false
  defp do_apply_shadow_edits(server_shadow, backup_shadow, [edit | edits]) do
    cond do
      # Ideal, we are on the same page:
      server_shadow.client_version == edit["localVersion"] ->
        patch_shadow_edits server_shadow, backup_shadow, edit, edits

      # Not ideal, but we already saw this client version. Throw away edit.
      server_shadow.client_version > edit["localVersion"] ->
        apply_shadow_edits server_shadow, backup_shadow, edits

      true ->
        {:error, %{
          reason: :no_matching_client_version,
          shadow_client_version: server_shadow.client_version,
          client_client_version: edit["localVersion"],
          edit: edit
        }}
    end
  end
  defp patch_shadow_edits(server_shadow, backup_shadow, edit, edits) do
    case diff_patch.patch(server_shadow.doc, edit["diff"]) do
      {:ok, new_doc} ->
        server_shadow =
          server_shadow
          |> Map.put(:doc, new_doc)
          |> Map.update!(:client_version, &(&1 + 1))

        apply_shadow_edits server_shadow, backup_shadow, edits

      {:error, reason} -> {:error, reason}
    end
  end
end

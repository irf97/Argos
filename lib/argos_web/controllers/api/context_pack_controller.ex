defmodule ArgosWeb.Api.ContextPackController do
  use ArgosWeb, :controller

  alias Argos.Context.Packs

  def create(conn, params) do
    case Packs.create_pack(params) do
      {:ok, context_pack} ->
        conn
        |> put_status(:created)
        |> json(%{context_pack: context_pack_json(context_pack)})

      {:error, :task_required} ->
        validation_error(conn, :task, "is required")

      {:error, :canon_required} ->
        validation_error(conn, :canon, "is required")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset_errors(changeset)})
    end
  end

  def show(conn, %{"hash" => hash}) do
    case Packs.get_pack_by_hash(hash) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "context pack not found"})

      context_pack ->
        json(conn, %{context_pack: context_pack_json(context_pack)})
    end
  end

  defp context_pack_json(context_pack) do
    %{
      id: context_pack.id,
      hash: context_pack.hash,
      task: context_pack.task,
      canon: context_pack.canon,
      canon_versions: context_pack.canon_versions,
      operator_state_id: context_pack.operator_state_id,
      retrieval_policy: context_pack.retrieval_policy,
      skill_refs: context_pack.skill_refs,
      payload: context_pack.payload,
      markdown: context_pack.markdown,
      compiled_at: DateTime.to_iso8601(context_pack.compiled_at)
    }
  end

  defp validation_error(conn, field, message) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{errors: %{field => [message]}})
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end

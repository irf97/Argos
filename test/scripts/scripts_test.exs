defmodule Argos.ScriptsTest do
  use ExUnit.Case, async: true

  @scripts ~w(scripts/argos scripts/codex-start.sh scripts/codex-end.sh)

  test "phase 5 scripts exist" do
    Enum.each(@scripts, &assert(File.exists?(&1)))
  end

  test "phase 5 scripts parse in bash when available" do
    case System.find_executable("bash") do
      nil ->
        :ok

      bash ->
        Enum.each(@scripts, fn script ->
          assert {_, 0} = System.cmd(bash, ["-n", script])
        end)
    end
  end
end

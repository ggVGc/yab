defmodule YAB.TestCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      defp new_keys() do
        private = YAB.KeyGenerator.gen_private()

        %{
          private: private,
          public: YAB.KeyGenerator.public_from_private(private)
        }
      end

      @miner_account YAB.KeyGenerator.public_from_private(YAB.KeyGenerator.gen_private())
    end
  end
end

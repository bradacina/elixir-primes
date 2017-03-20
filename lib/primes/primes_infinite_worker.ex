defmodule Primes.InfiniteWorker do

    def start(identifier) do
        spawn(__MODULE__, :init_process, [identifier])
    end

    def init_process(identifier) do
        send(:"Primes.Server", {:ready, self()})
        loop(identifier)
    end

    def give_work(worker, num) do
        send(worker, {:check, num, self()})
    end

    defp loop(identifier) do
        receive do
            {:check, num, _} ->
                IO.puts(to_string(identifier) <> " received work " <> to_string(num))
                :ok
            
            other -> 
                IO.inspect(other, label: to_string(identifier) <> " Received Unknown Message")
        end

        loop(identifier)
    end
end
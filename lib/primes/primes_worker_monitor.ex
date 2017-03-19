defmodule Primes.WorkerMonitor do
    @num_workers 10

    def start() do
        spawn(__MODULE__, :init, [])
    end

    def init() do
        (1..@num_workers)
            |> Enum.map(&start_initial(&1))
            |> Enum.into(%{})
            |> loop()
    end

    defp loop(map) do
        map = receive do
            {:DOWN, _, :process, pid, _} ->
                start_worker(map, pid)
            _ -> map
        end
        
        loop(map)
    end

    defp start_initial(identifier) do
        {pid, _} = spawn_monitor(Primes.Worker, :init_process, [identifier])

        {pid, identifier}
    end

    defp start_worker(map, pid) do
        identifier = Map.get(map, pid)
        IO.puts("Restarting worker " <> to_string(identifier))
        {newpid, _} = spawn_monitor(Primes.Worker, :init_process, [identifier])
        
        map
            |> Map.delete(pid)
            |> Map.put(newpid, identifier)
    end
end
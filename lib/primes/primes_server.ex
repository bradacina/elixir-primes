defmodule Primes.Server do
    
    @num_workers 10

    def run do
        server = spawn(__MODULE__, :loop, [{[],[],[]}])
        worker_pids = 
        (1..@num_workers)
            |> Enum.each(&start_worker(&1, server))
        IO.inspect(worker_pids)

        # return the server's pid
        server
    end

    def is_prime(server, num) do
        send(server, {:compute, num})
    end

    defp start_worker(id, server) do
        Primes.Worker.start(id, server)
    end

    def loop(state) do
        receive do
            {:ready, worker} ->
                add_new_worker(state, worker)
                |> loop()
                
            {:true, num, worker } ->
                IO.puts(to_string(num) <> " is a prime")
                add_free_worker(state, worker)
                |> loop()
                
            {:false, num, worker } ->
                IO.puts(to_string(num) <> " is NOT a prime")
                add_free_worker(state, worker)
                |> loop()
            
            {:compute, num } ->
                add_work(state, num)
                |> loop()
        end
    end

    defp add_new_worker({all_workers, free_workers, queued_work}, worker) do
        all_workers = [worker | all_workers]
        free_workers = [worker | free_workers]
        give_work({all_workers, free_workers, queued_work})
    end

    defp add_free_worker({all_workers, free_workers, queued_work}, worker) do
        free_workers = [worker | free_workers]
        give_work({all_workers, free_workers, queued_work})
    end

    defp add_work({all_workers, free_workers, queued_work}, work) do
        queued_work = [work | queued_work]
        give_work({all_workers, free_workers, queued_work})
    end

    defp give_work(state = {all_workers, free_workers, queued_work}) do
        if Enum.count(queued_work) > 0 && Enum.count(free_workers) > 0 do
            [work| rest_work] = queued_work
            [worker| rest_workers] = free_workers
            Primes.Worker.give_work(worker, work)
            {all_workers, rest_workers, rest_work}
        else
            # no available workers or no available work
            # so just return the original state
            state
        end
    end
end
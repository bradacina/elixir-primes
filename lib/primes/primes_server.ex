defmodule Primes.Server do
    
    defstruct free_workers: [],
        work_queue: [],
        file: nil

    @num_workers 10

    @max_queue 10000

    @backoff_ms 100

    def run do
        state = %Primes.Server{}
        {:ok, file} = File.open("out.txt", [:write, :utf8])
        state = %{state| file: file}
        server = spawn(__MODULE__, :loop, [state])
        worker_pids = 
        (1..@num_workers)
            |> Enum.each(&start_worker(&1, server))
        IO.inspect(worker_pids)

        # return the server's pid
        server
    end

    def is_prime(server, num) do
        is_prime_retry(server,num)
    end

    defp is_prime_retry(server, num) do
        send(server, {:compute, num, self()})
        receive do
            :ok -> :ok
        after @backoff_ms ->
            is_prime_retry(server,num)
        end
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
                IO.puts(state.file, to_string(num) <> " is a prime")
                add_free_worker(state, worker)
                |> loop()
                
            {:false, _num, worker } ->
                #IO.puts(to_string(num) <> " is NOT a prime")
                add_free_worker(state, worker)
                |> loop()
            
            {:compute, num, sender } ->
                case throttle(state, sender) do
                    :ok ->
                        add_work(state, num)
                        |> loop()
                    _ ->
                        loop(state)
                end
        end
    end

    defp throttle(state, sender) do
        if Enum.count(state.work_queue) < @max_queue do
            send(sender, :ok)
            :ok
        else
            :back_off
        end
    end

    defp add_new_worker(state, worker) do
        more_free_workers = [worker | state.free_workers]
        state = %{state| free_workers: more_free_workers}
        give_work(state)
    end

    defp add_free_worker(state, worker) do
        more_free_workers = [worker | state.free_workers]
        state = %{state| free_workers: more_free_workers}
        give_work(state)
    end

    defp add_work(state, work) do
        more_work = [work | state.work_queue]
        state = %{state| work_queue: more_work}
        give_work(state)
    end

    defp give_work(state) do
        
        if Enum.count(state.work_queue) > 0 && Enum.count(state.free_workers) > 0 do
            [work| rest_work] = state.work_queue
            [worker| rest_workers] = state.free_workers
            Primes.Worker.give_work(worker, work)
            state = %{state |work_queue:  rest_work}
            state = %{state| free_workers: rest_workers}
            state
        else
            # no available workers or no available work
            # so just return the original state
            state
        end
    end
end
defmodule Primes.Server do
    
    defstruct free_workers: [],
        work_queue: [],
        file: nil,
        working_on: %{}

    @max_queue 10000

    @backoff_ms 100

    @server_name :"Primes.Server"

    def run do
        stop()
        state = %Primes.Server{}
        {:ok, file} = File.open("out.txt", [:write, :utf8])
        state = %{state| file: file}
        server = spawn(__MODULE__, :loop, [state])
        Process.register(server, @server_name)
        Primes.WorkerMonitor.start()
        :ok
    end

    defp stop() do
        is_registered = Process.registered |> Enum.find(fn x -> x == @server_name end)

        if is_registered do
            Process.unregister(@server_name)
        end
    end

    def worker_quit(worker) do
        send(@server_name, {:worker_quit, worker})
    end

    def is_prime(num) do
        is_prime_retry(num)
    end

    defp is_prime_retry(num) do
        send(@server_name, {:compute, num, self()})
        receive do
            :ok -> :ok
        after @backoff_ms ->
            is_prime_retry(num)
            {:failed, :backed_up}
        end
    end

    def loop(state) do
        receive do
            {:state} ->
                IO.inspect(state)

            {:ready, worker} ->
                add_new_worker(state, worker)
                
            {:true, num, worker } ->
                IO.puts(state.file, to_string(num) <> " is a prime")
                add_free_worker(state, worker)
                
            {:false, _num, worker } ->
                #IO.puts(to_string(num) <> " is NOT a prime")
                add_free_worker(state, worker)

            {:worker_quit, worker } ->
                handle_worker_quit(state, worker)

            {:compute, num, sender } ->
                case throttle(state, sender) do
                    :ok ->
                        add_work(state, num)
                    _ ->
                        state
                end
        end
        |> loop()
    end

    defp throttle(state, sender) do
        if Enum.count(state.work_queue) < @max_queue do
            send(sender, :ok)
            :ok
        else
            :back_off
        end
    end

    defp handle_worker_quit(state, worker) do
        {work, state} = pop_in(state.working_on[worker])
        add_work(state, work)
    end

    defp add_new_worker(state, worker) do
        more_free_workers = [worker | state.free_workers]
        state = %{state| free_workers: more_free_workers}
        give_work(state)
    end

    defp add_free_worker(state, worker) do
        {_, state} = pop_in(state.working_on[worker])
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
            state = put_in(state.working_on[worker], work)
            Primes.Worker.give_work(worker, work)
            state = %{state | work_queue:  rest_work}
            state = %{state| free_workers: rest_workers}
            state
        else
            # no available workers or no available work
            # so just return the original state
            state
        end
    end
end
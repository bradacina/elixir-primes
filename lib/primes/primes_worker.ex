defmodule Primes.Worker do

    def start(identifier, server) do
        spawn(__MODULE__, :init_process, [identifier,server])
    end

    def init_process(identifier, server) do
        :rand.seed({:exsplus, [130428040511557832 | 67138277533366280]})
        send(server, {:ready, self()})
        loop(identifier)
    end

    def give_work(worker, num) do
        send(worker, {:check, num, self()})
    end

    defp loop(identifier) do
        receive do
            {:check, num, sender} ->
                send(sender, { prime_check(num), num, self()})
                loop(identifier)
            
            other -> 
                IO.inspect(other, label: to_string(identifier) <> " Received Unknown Message")
        end
    end

    defp prime_check(number) do
        prime_check(number, 10)
    end

    defp prime_check(number, 0) do
        fermat(number)
    end

    defp prime_check(number, times) do
        if fermat(number) do
            prime_check(number, times-1)
        else
            :false
        end
    end


    defp mpow(n,1,_) do
        n
    end

    defp mpow(n, k, m) do
        mpow(rem(k,2), n,k,m)
    end

    defp mpow(0,n,k,m) do
        x = mpow(n, div(k,2), m)
        rem(x*x, m) 
    end

    defp mpow(_, n,k,m) do
        x = mpow(n,k-1, m)
        rem(x*n, m)
    end

    defp fermat(1) do
        :true
    end

    defp fermat(p) do
        r = :rand.uniform(p-2) +1
        t = mpow(r, p-1, p)
        if t == 1 do
            :true
        else 
            :false
        end
    end

end
defmodule Server do
  def join(master_pid, server) do
    client = server |> Socket.Web.accept!
    client |> Socket.Web.accept!

    spawn fn -> receive_msg(master_pid, client) end
    send(master_pid, {:join, client})

    join(master_pid, server)
  end

  def receive_msg(master_pid, client) do
    case client |> Socket.Web.recv! do
      {:text, msg} ->
        {ok?, state} = JSON.decode(msg)
        send(master_pid, {:broadcast_msg, state})
      {:close, _, _} ->
        send(master_pid, {:close, client})
        Process.exit(self(), "user left")
      other ->        IO.inspect other
    end

    receive_msg(master_pid, client)
  end

  def chat(clients) do
    clients |> length |> IO.puts
    main_pid = self()
    receive do
      {:join, client} ->
        IO.puts "joined"
        next_clients = [client|clients]
        spawn fn -> send(main_pid, {:online_count, length(next_clients)}) end
        chat(next_clients)
      {:close, client} ->
        IO.puts "left"
        next_clients = List.delete(clients, client)
        spawn fn -> send(main_pid, {:online_count, length(next_clients)}) end
        chat(next_clients)
      {:online_count, count} ->
        Enum.each clients, fn(client) ->
          spawn fn -> client |> Socket.Web.send!({:text, "{ \"online_count\": #{count} }"}) end
        end
        chat(clients)
      {:broadcast_msg, state} ->
        Enum.each clients, fn(client) ->
          {ok?, msg} = JSON.encode(state)
          spawn fn -> client |> Socket.Web.send!({:text, msg}) end
        end
        chat(clients)
    end
  end
end

master_pid = self()
spawn fn ->
  server = Socket.Web.listen! 5000
  Server.join(master_pid, server)
end

Server.chat([])